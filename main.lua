local love = love
local lg = love.graphics

lg.setDefaultFilter("nearest", "nearest")

local math = math
local floor = math.floor

local tiny = 0.00000000000001

local cpml = require "cpml"
local vec3 = cpml.vec3
local intersect = cpml.intersect
local mat4 = cpml.mat4

local function reflect(dir, normal)
  local dot = vec3.dot(dir, normal)
  return dir - (normal * (2 * dot))
end

local function vectorAngle(a, b)
  return math.acos(a:dot(b) / (a:len() * b:len()))
end

local function withinCone(a, b, angle)
  return vectorAngle(a, b) <= angle
end

local skyColor1 = vec3(63/255, 88/255, 226/255)
local skyColor2 = vec3(173/255, 226/255, 255/255)

local shadowMul = 0.5

local planeColor1 = vec3(0.2, 0.9, 0.2)
local planeColor2 = vec3(0.1, 0.4, 0.1)

local function sphereNormal(pos, obj)
  return (pos - obj.position):normalize()
end

local objects = {
  {
    intersect = intersect.ray_plane,
    position = vec3(0, -1, 0),
    normal = vec3(0, 1, 0),
    color = function(position)
      return (floor(position.x) + floor(position.z) % 2) % 2 == 0 and planeColor1 or planeColor2
    end
  },
  {
    intersect = intersect.ray_sphere,
    position = vec3(-0.8, -0.5, 0),
    radius = 0.5,
    color = vec3(1, 0, 0),
    normal = sphereNormal,
  },
  {
    intersect = intersect.ray_sphere,
    position = vec3(0.8, -0.5, 0),
    radius = 0.5,
    color = vec3(1, 1, 1),
    normal = sphereNormal,
    reflect = 1
  }
}

local sunDir = vec3(1, 1, 0.5):normalize()

local sunColor = vec3(0.9, 0.9, 0.8)
local sunAngle = 0.1

local maxBounces = 3

local function castRay(ray, shadowCheck, count, ignore)
  count = count or 1
  
  local lastInter
  
  for _, obj in pairs(objects) do
    if obj ~= ignore then
      local pos, dist = obj.intersect(ray, obj)
      if pos and (not lastInter or dist < lastInter.dist) then
        if shadowCheck then return true end
        lastInter = {pos=pos, dist=dist, obj=obj}
      end
    end
  end
  
  if lastInter then
    local color = lastInter.obj.color
    color = type(color) == "function" and color(lastInter.pos) or color
    
    local normal = lastInter.obj.normal
    normal = type(normal) == "function" and normal(lastInter.pos, lastInter.obj) or normal
    
    local hitPos = lastInter.pos + normal * tiny
    
    if lastInter.obj.reflect and count < maxBounces then
      local reflection = castRay({position = hitPos, direction = reflect(ray.direction, normal)}, false, count + 1)
      
      color = color * (reflection * lastInter.obj.reflect)
    end
    
    color = color * math.max(vec3.dot(sunDir, normal) ^ 0.7, shadowMul ^ 2)
    
    local shadow = castRay({position = hitPos, direction = sunDir}, true, 0, lastInter.obj)
    
    if shadow then
      color = color * shadowMul
    end
    
    return color
  end
  
  if shadowCheck then return false end
  
  local angle = vectorAngle(ray.direction, sunDir)
  
  local skyColor = vec3.lerp(skyColor1, skyColor2, ray.direction.y ^ 2)
  
  return angle <= sunAngle and vec3.lerp(sunColor, skyColor, (angle / sunAngle) ^ 5) or skyColor
end

local scale = 2

local imgData = love.image.newImageData(lg.getWidth() / scale, lg.getHeight() / scale)
local screenW, screenH = imgData:getDimensions()

local ratio = screenW / screenH

local origCamPosition = vec3(0, 0, 2)

local ray = {
  position = origCamPosition,
  direction = vec3(),
  direction4 = {}
}

local camMatrix = mat4()

local function screen()
  for x=0, imgData:getWidth() - 1 do
    for y=0, imgData:getHeight() - 1 do
      ray.direction.x = (x / screenW - 0.5) * 2 * ratio
      ray.direction.y = -(y / screenH - 0.5) * 2
      ray.direction.z = -1
      ray.direction = ray.direction:normalize()
      ray.direction4[1] = ray.direction.x
      ray.direction4[2] = ray.direction.y
      ray.direction4[3] = ray.direction.z
      ray.direction4[4] = 0
      mat4.mul_vec4(ray.direction4, camMatrix, ray.direction4)
      ray.direction.x = ray.direction4[1]
      ray.direction.y = ray.direction4[2]
      ray.direction.z = ray.direction4[3]
      local color = castRay(ray)
      imgData:setPixel(x, y, color.x, color.y, color.z, 1)
    end
  end
end

local maxIters = 120

for i=0, maxIters - 1 do
  camMatrix:identity()
  local angle = i / maxIters * math.pi * 2
  camMatrix:rotate(camMatrix, angle, vec3.unit_y)
  ray.position = camMatrix * origCamPosition
  camMatrix:rotate(camMatrix, -0.2, vec3.unit_x)
  screen()
  imgData:encode("png", "thing_" .. i .. ".png")
  lg.clear()
  lg.print(i + 1 .. "/" .. maxIters)
  lg.present()
end

local img = lg.newImage(imgData)

function love.draw()
  lg.draw(img, 0, 0, 0, scale, scale)
end