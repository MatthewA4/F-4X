#Copyright (C) 2018 Matthew Anderson
#Licensed under GPLv2+

#version 150

varying vec2 uv;
varying vec3 to_Fragment;

uniform mat4 modelProjection;
uniform mat4 modelViewMatrix;
uniform mat3 normalMatrix;

uniform sampler2D roughness;
uniform sampler2D frostmap;
uniform sampler2D albedo;


attribute vec3 vert;
attribute vec2 uvImport;
attribute vec3 normalVector;

void main()
{


  gl_FragColor =
}
