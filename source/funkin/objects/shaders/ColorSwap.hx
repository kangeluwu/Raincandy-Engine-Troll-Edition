package funkin.objects.shaders;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
class ColorSwap
{
	public var shader(default, null):ColorSwapShader = new ColorSwapShader();
	
	public var hue(default, set):Float = 0;
	public var saturation(default, set):Float = 0;
	public var brightness(default, set):Float = 0;
	public var daAlpha(default, set):Float = 1;
	public var flash(default, set):Float = 0;

	public var usePixel(default, set):Bool = false;

	public var flashR(default, set):Float = 1;
	public var flashG(default, set):Float = 1;
	public var flashB(default, set):Float = 1;
	public var flashA(default, set):Float = 1;
	public var size(default, set):Array<Float> = [FlxG.width/32,FlxG.height/32];

	public var r(default, set):FlxColor;
	public var g(default, set):FlxColor;
	public var b(default, set):FlxColor;
	public var mult(default, set):Float;

	private function set_r(color:FlxColor) {
		r = color;
		shader.r.value = [color.redFloat, color.greenFloat, color.blueFloat];
		return color;
	}

	private function set_g(color:FlxColor) {
		g = color;
		shader.g.value = [color.redFloat, color.greenFloat, color.blueFloat];
		return color;
	}

	private function set_b(color:FlxColor) {
		b = color;
		shader.b.value = [color.redFloat, color.greenFloat, color.blueFloat];
		return color;
	}
	
	private function set_mult(value:Float) {
		mult = FlxMath.bound(value, 0, 1);
		shader.mult.value = [mult];
		return mult;
	}

	private function set_usePixel(value:Bool)
	{
			usePixel = value;
			shader.usePixel.value[0] = value;
			return value;
	}
	private function set_size(value:Array<Float>)
	{
			size = value;
			shader.uBlocksize.value[0] = size[0] * 32;
			shader.uBlocksize.value[1] = size[1] * 32;
			return size;
	}

	private function set_flashR(value:Float)
	{
		flashR = value;
		shader.flashColor.value[0] = flashR;
		return flashR;
	}

	private function set_flashG(value:Float)
	{
		flashG = value;
		shader.flashColor.value[1] = flashG;
		return flashG;
	}

	private function set_flashB(value:Float)
	{
		flashB = value;
		shader.flashColor.value[2] = flashB;
		return flashB;
	}

	private function set_flashA(value:Float)
	{
		flashA = value;
		shader.flashColor.value[3] = flashA;
		return flashA;
	}

	private function set_daAlpha(value:Float)
	{
		daAlpha = value;
		shader.daAlpha.value[0] = daAlpha;
		return daAlpha;
	}

	private function set_flash(value:Float)
	{
		flash = value;
		shader.flash.value[0] = flash;
		return flash;
	}

	private function set_hue(value:Float)
	{
		hue = value;
		shader.uTime.value[0] = hue;
		return hue;
	}

	private function set_saturation(value:Float)
	{
		saturation = value;
		shader.uTime.value[1] = saturation;
		return saturation;
	}

	private function set_brightness(value:Float)
	{
		brightness = value;
		shader.uTime.value[2] = brightness;
		return brightness;
	}
	public function copyFrom(parent:ColorSwap){
		this.r = parent.r;
		this.g = parent.g;
		this.b = parent.b;
		this.mult = parent.mult;


		this.hue = parent.hue;
		this.saturation = parent.saturation;
		this.brightness = parent.brightness;
		this.daAlpha = parent.daAlpha;

		this.usePixel = parent.usePixel;
		this.size = parent.size;
		this.flash = parent.flash;
		this.flashR = parent.flashR;
		this.flashG = parent.flashG;
		this.flashB = parent.flashB;
		this.flashA = parent.flashA;
	}

	public function clone():ColorSwap
		{
			var parent = new ColorSwap();
			parent.r = this.r;
			parent.g = this.g;
			parent.b = this.b;
			parent.mult = this.mult;


			parent.hue = this.hue;
			parent.saturation = this.saturation;
			parent.brightness = this.brightness;
			parent.daAlpha = this.daAlpha;

			parent.usePixel = this.usePixel;
			parent.size = this.size;
			parent.flash = this.flash;
			parent.flashR = this.flashR;
			parent.flashG = this.flashG;
			parent.flashB = this.flashB;
			parent.flashA = this.flashA;
			return parent;
		}
	public function new()
	{
		r = 0xFFFF0000;
		g = 0xFF00FF00;
		b = 0xFF0000FF;
		mult = 1.0;
		shader.uTime.value = [0, 0, 0];
		shader.flashColor.value = [1, 1, 1, 1];
		shader.daAlpha.value = [1];
		shader.flash.value = [0];
		shader.uBlocksize.value = [FlxG.width/32,FlxG.height/32];
		shader.usePixel.value = [false];
	}
}

class ColorSwapShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header
		uniform vec3 r;
		uniform vec3 g;
		uniform vec3 b;
		uniform float mult;
		uniform bool usePixel = false;
		uniform vec3 uTime;
		uniform float daAlpha;
		uniform float flash;
		uniform vec4 flashColor;
		uniform vec2 uBlocksize;
		const float offset = 1.0 / 128.0;
		vec2 fragCoord = openfl_TextureCoordv*openfl_TextureSize;
		vec2 iResolution = openfl_TextureSize;
		vec3 normalizeColor(vec3 color)
		{
			return vec3(
				color[0] / 255.0,
				color[1] / 255.0,
				color[2] / 255.0
			);
		}

		vec3 rgb2hsv(vec3 c)
		{
			vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
			vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
			vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

			float d = q.x - min(q.w, q.y);
			float e = 1.0e-10;
			return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
		}

		vec3 hsv2rgb(vec3 c)
		{
			vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
			vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
			return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
		}

        vec4 colorMult(vec4 color){
            if (!hasTransform)
			{
				return color;
			}

			if (color.a == 0.0)
			{
				return vec4(0.0, 0.0, 0.0, 0.0);
			}

			if (!hasColorTransform)
			{
				return color * openfl_Alphav;
			}

			color = vec4(color.rgb / color.a, color.a);

			mat4 colorMultiplier = mat4(0);
			colorMultiplier[0][0] = openfl_ColorMultiplierv.x;
			colorMultiplier[1][1] = openfl_ColorMultiplierv.y;
			colorMultiplier[2][2] = openfl_ColorMultiplierv.z;
			colorMultiplier[3][3] = openfl_ColorMultiplierv.w;

			color = clamp(openfl_ColorOffsetv + (color * colorMultiplier), 0.0, 1.0);

			if (color.a > 0.0)
			{
				return vec4(color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);
			}

            return vec4(0.0, 0.0, 0.0, 0.0);
        }

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 coord) {
			vec4 color = texture2D(bitmap, coord);
			if (!hasTransform || color.a == 0.0 || mult == 0.0) {
				return color;
			}

			vec4 newColor = color;
			newColor.rgb = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
			newColor.a = color.a;
			
			color = mix(color, newColor, mult);
			
			if(color.a > 0.0) {
				return vec4(color.rgb, color.a);
			}
			return vec4(0.0, 0.0, 0.0, 0.0);
		}

		void main()
		{
			vec2 uv = fragCoord/iResolution.xy;
			vec2 blocks = uv / uBlocksize;
			vec4 color = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
			if (usePixel)
				 color = flixel_texture2DCustom(bitmap, floor(openfl_TextureCoordv * uBlocksize) / uBlocksize);
			vec4 swagColor = vec4(
				rgb2hsv(
					vec3(color[0], color[1], color[2])
				), 
				color[3]
			);

			// hue
			swagColor[0] = swagColor[0] + uTime[0];
			// sat
			swagColor[1] = swagColor[1] * (1.0 + uTime[1]);
			// val
			swagColor[2] = swagColor[2] * (1.0 + uTime[2]);
			
			if(swagColor[1] < 0.0)
			{
				swagColor[1] = 0.0;
			}
			else if(swagColor[1] > 1.0)
			{
				swagColor[1] = 1.0;
			}

			color = vec4(hsv2rgb(vec3(swagColor[0], swagColor[1], swagColor[2])), swagColor[3]);

			if(flash != 0.0){
				color = mix(color, flashColor, flash) * color.a;
			}
			color *= daAlpha;
			gl_FragColor = colorMult(color);

		}')
	public function new()
	{
		super();
	}
}