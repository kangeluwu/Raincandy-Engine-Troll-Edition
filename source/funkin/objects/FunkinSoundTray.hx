package funkin.objects;

import flixel.system.ui.DefaultFlxSoundTray;
import flixel.tweens.FlxTween;
import flixel.system.FlxAssets;
import flixel.tweens.FlxEase;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.utils.Assets;
import funkin.CoolUtil;
import funkin.Paths;
/**
 *  Extends the default flixel soundtray, but with some art
 *  and lil polish!
 *
 *  Gets added to the game in Main.hx, right after FlxGame is new'd
 *  since it's a Sprite rather than Flixel related object
 */
class FunkinSoundTray extends DefaultFlxSoundTray
{
  var graphicScale:Float = 0.30;
  var lerpYPos:Float = 0;
  var alphaTarget:Float = 0;

  var volumeMaxSound:String;

  public function new()
  {
    // calls super, then removes all children to add our own
    // graphics
    super();
    removeChildren();

    var bg:Bitmap = new Bitmap(BitmapData.fromFile(Paths.getPath("images/soundtray/volumebox.png")));
    bg.scaleX = graphicScale;
    bg.scaleY = graphicScale;
    addChild(bg);

    y = -height;
    visible = false;

    // makes an alpha'd version of all the bars (bar_10.png)
    var backingBar:Bitmap = new Bitmap(BitmapData.fromFile(Paths.getPath("images/soundtray/bars_10.png")));
    backingBar.x = 9;
    backingBar.y = 5;
    backingBar.scaleX = graphicScale;
    backingBar.scaleY = graphicScale;
    addChild(backingBar);
    backingBar.alpha = 0.4;

    // clear the bars array entirely, it was initialized
    // in the super class
    _bars = [];

    // 1...11 due to how block named the assets,
    // we are trying to get assets bars_1-10
    for (i in 1...11)
    {
      var bar:Bitmap = new Bitmap(BitmapData.fromFile(Paths.getPath("images/soundtray/bars_"+i+'.png')));
      bar.x = 9;
      bar.y = 5;
      bar.scaleX = graphicScale;
      bar.scaleY = graphicScale;
      addChild(bar);
      _bars.push(bar);
    }

    y = -height;
    screenCenter();

    volumeUpSound = Paths.returnSoundPath("sounds","soundtray/Volup");
    volumeDownSound =Paths.returnSoundPath("sounds","soundtray/Voldown");
    volumeMaxSound = Paths.returnSoundPath("sounds","soundtray/VolMAX");

    trace("Custom tray added!");
  }

  override public function update(MS:Float):Void
  {
    y = CoolUtil.coolLerp(y, lerpYPos, 0.1);
    alpha = CoolUtil.coolLerp(alpha, alphaTarget, 0.25);

    // Animate sound tray thing
    if (_timer > 0)
    {
      _timer -= (MS / 1000);
      alphaTarget = 1;
    }
    else if (y >= -height)
    {
      lerpYPos = -height - 10;
      alphaTarget = 0;
    }

    if (y <= -height)
    {
      visible = false;
      active = false;

      #if FLX_SAVE
      // Save sound preferences
      saveVolumeData();
      #end
    }
  }

  /**
   * Makes the little volume tray slide out.
   *
   * @param	up Whether the volume is increasing.
   */
  override public function show(up:Bool = false):Void
  {
    _timer = 1;
    lerpYPos = 10;
    visible = true;
    active = true;
    var globalVolume:Int = Math.round(FlxG.sound.volume * 10);

    if (FlxG.sound.muted)
    {
      globalVolume = 0;
    }

    if (!silent)
    {
      var sound = up ? volumeUpSound : volumeDownSound;

      if (globalVolume == 10) sound = volumeMaxSound;

      if (sound != null) FlxG.sound.load(sound).play();
    }

    for (i in 0..._bars.length)
    {
      if (i < globalVolume)
      {
        _bars[i].visible = true;
      }
      else
      {
        _bars[i].visible = false;
      }
    }
  }
}
