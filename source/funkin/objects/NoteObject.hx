package funkin.objects;

import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import funkin.objects.shaders.ColorSwap;
enum abstract ObjectType(#if cpp cpp.UInt8 #else Int #end)
{
	var UNKNOWN = -1;
	var NOTE;
	var STRUM;
	var SPLASH;
	var HOLD;
}

class NoteObject extends FlxSprite {
	public var objType:ObjectType = UNKNOWN;
	public var colorSwap:ColorSwap = new ColorSwap();
    public var column:Int = 0;
    @:isVar
    public var noteData(get,set):Int; // backwards compat
    inline function get_noteData()return column;
    inline function set_noteData(v:Int)return column = v;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var defScale:FlxPoint = FlxPoint.get(); // for modcharts to keep the scaling
	public var handleRendering:Bool = true;
	
	override function toString()
	{
		return '(column: $column | visible: $visible)';
	}

	override function draw()
	{
		if (handleRendering)
			return super.draw();
	}

	public function new(?x:Float, ?y:Float){
		super(x, y);
	}

	public function defaultRGB()
		{
		var shader = new ColorSwap();
		
		var arr:Array<FlxColor> = ClientPrefs.arrowRGB[column];

		if (arr != null && column > -1 && column <= arr.length)
		{
			shader.r = arr[0];
			shader.g = arr[1];
			shader.b = arr[2];
		}
		else
		{
			shader.r = 0xFFFF0000;
			shader.g = 0xFF00FF00;
			shader.b = 0xFF0000FF;
		}
		return shader;
		}

	override function destroy()
	{
		defScale = FlxDestroyUtil.put(defScale);
		super.destroy();
	}
}