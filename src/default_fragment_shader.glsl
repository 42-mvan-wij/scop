#version 330 core

out vec4 color;

uniform sampler2D myTextureSampler;
uniform float t = 0.5;

flat in vec3 vertexCol;
in vec2 UV;

void main() {
	float pct = smoothstep(0.0, 1.0, t);
	vec3 texture_color = texture(myTextureSampler, UV).rgb;
	vec3 gray_color = vec3(vertexCol.r + vertexCol.g + vertexCol.b) / 3;
	color = vec4(mix(gray_color, texture_color, pct), 1.0);
}
