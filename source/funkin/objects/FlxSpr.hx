package funkin.objects;

import flixel.math.FlxPoint;
import flixel.graphics.frames.FlxFrame;
import openfl.geom.Rectangle;
import openfl.geom.Matrix;
import openfl.display.Sprite;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
/**
 * FlxSprite to Sprite.
 */
class FlxSpr extends Sprite
{
  var mat:Matrix;
  var spr:Sprite;
  var lastFrame:FlxFrame;
  var targetSprite(get,never):FlxSprite;
  public var currentSprite:FlxSprite = null;
  public var spr_instance:Dynamic;
  public var spr_variable:String;
  public var offset(default,null):FlxPoint;
  public function new(instance:Dynamic, variable:String,curSpr:FlxSprite = null)
  {
    super();
    if (curSpr != null)
      currentSprite = curSpr;
    mat = new Matrix();
    mat.translate(0,0);
    spr_instance = instance;
    spr_variable = variable;
    spr = new Sprite();

    spr.graphics.beginBitmapFill(targetSprite.pixels, mat);
    spr.graphics.drawRect(0, 0, targetSprite.pixels.width, targetSprite.pixels.height);
    spr.graphics.endFill();

    scrollRect = new Rectangle();
    addChild(spr);
    @:privateAccess
    lastFrame = targetSprite._frame;
    offset = FlxPoint.get();
  }

  function getSprite():FlxSprite
  {
    if (Reflect.getProperty(spr_instance, spr_variable) == null && currentSprite == null)
      throw "Null Object Reference";
    else{
    if (currentSprite != null){
        return currentSprite;
      }else{
        return Reflect.getProperty(spr_instance, spr_variable);
      }
    }
  }

  public function drawShits()
  {
    if (targetSprite == null || spr == null) return;
    @:privateAccess
    var frame = targetSprite._frame;
    scrollRect = new Rectangle(frame.frame.x, frame.frame.y, frame.frame.width, frame.frame.height);
    if (lastFrame != null && frame != null && lastFrame.name != frame.name) 
    {
      spr.graphics.clear();
      mat =  new Matrix();
      mat.translate(0,0);
      spr.graphics.beginBitmapFill(targetSprite.pixels, mat);
      spr.graphics.drawRect(0,0,targetSprite.pixels.width,targetSprite.pixels.height);
      spr.graphics.endFill();
      lastFrame = frame;
    }

    var xPos = (((frame.offset.x) - (targetSprite.offset.x)) * scaleX);
    var yPos = (((frame.offset.y) - (targetSprite.offset.y)) * scaleY);

    xPos += offset.x;
    yPos += offset.y;

    x = xPos;
    y = yPos;
  }

  override function __enterFrame(deltaTime:Float):Void
  {
    // better performance
    if (!visible) return;
    drawShits();
  }

  function get_targetSprite() return getSprite();
}