#Copyright (C) 2018 Matthew Anderson
#Licensed under GPLv2+

#version 150

uniform mat4 modelProjection;
uniform mat4 modelViewMatrix;
uniform mat3 normalMatrix;

out varying vec2 uv;
out varying vec3 to_Fragment;


void main()
{
  gl_Position = modelProjection * vec4(vert, 1.0);

  uv = uvImport;

  to_Fragment = normalize(normalMatrix * normalVector);
}
