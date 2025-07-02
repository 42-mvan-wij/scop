#version 330 core

uniform mat4 MVP;
uniform mat4 ModelToWorld;

uniform vec3 image_up = vec3(0.0, 1.0, 0.0);
uniform vec3 image_right = vec3(1.0, 0.0, 0.0);
uniform vec3 image_origin = vec3(0.0, 0.0, 0.0);

in vec3 vPos; // In model space

flat out vec3 vertexCol;
out vec2 UV;

void main() {
    gl_Position = MVP * vec4(vPos, 1.0);
	// vec3 world_pos = (ModelToWorld * vec4(vPos, 1.0)).xyz;
	vec3 world_pos = vPos;
	vertexCol = fract(vPos);
	// float id = (gl_VertexID % 5) / 4.0;
	// vertexCol = vec3(id * 0.6 + 0.2);
	UV = vec2(dot(world_pos - image_origin, image_right) + 0.5, -dot(world_pos - image_origin, image_up) + 0.5);
}
