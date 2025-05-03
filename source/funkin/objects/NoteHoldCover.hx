package funkin.objects;

//VICEVERSA SUSTAIN NOTE SPLASHES LOL
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import math.*;
import funkin.states.PlayState;
import flixel.math.FlxPoint;
using StringTools;
import flixel.addons.effects.FlxSkewedSprite;
import funkin.objects.shaders.ColorSwap;
import funkin.scripts.FunkinHScript;
class NoteHoldCover extends NoteObject
{
	//public var names:Array<String> = ['Purple','Blue','Green','Red'];
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;
	public var angleAdd:Float = 0;
	public var sprTracker:FlxSprite;
	public var resetAnim:Float = 0;
	public var playHoldEnd:Bool = false;
	private var textureLoaded:String = null;
	public var started:Bool = false;
	public var vec3Cache:Vector3 = new Vector3();
	public var texture(default, set):String;
	public var noteMod(default, set):String;
    public var genScript:FunkinHScript;
	private function set_texture(value:String):String {
        if (textureLoaded != value) {
			textureLoaded = value;
			reloadHold(value);
		};
		texture = value;
        return value;
	}
	function set_noteMod(value:String){
		if (PlayState.instance != null)
		{
            var script = PlayState.instance.hudSkinScripts.get(value);
            if(script == null){
				var baseFile = 'hudskins/$value.hscript';
				var files = [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)];
				for (file in files)
				{
					if (!Paths.exists(file))
						continue;
                    script = FunkinHScript.fromFile(file, value);
                    PlayState.instance.hscriptArray.push(script);
                    PlayState.instance.funkyScripts.push(script);
                    PlayState.instance.hudSkinScripts.set(value, script);
                }

            }
			genScript = script;
		}
		// trace(noteData);

		if (genScript != null && genScript.exists("setupHoldTexture"))
			genScript.executeFunc("setupHoldTexture", [this]);
		else{
			var skin:String = PlayState.holdSkin;
			if (skin == null || skin.length < 1)
				skin = 'holdCover';

			var newTex = (genScript != null && genScript.exists("texture")) ? genScript.get("texture") : skin;
			if (genScript != null)
			{
				if (genScript.exists("texturePrefix"))
					newTex = genScript.get("texturePrefix") + texture;

				if (genScript.exists("textureSuffix"))
					newTex += genScript.get("textureSuffix");
			}

			texture = newTex; // Load texture and anims
            
        }
		

        return noteMod = value;
    }
	public function new(?X:Float = 0, ?Y:Float = 0,noteNum:Int = 0, ?hudSkin:String = 'default')
		{
          super(X,Y);
		  objType = HOLD;
		  column = noteNum;
		  noteMod = hudSkin;

		  visible = false;
		 // antialiasing = ClientPrefs.globalAntialiasing;
		 colorSwap = new ColorSwap();
		 shader = colorSwap.shader;

		}
		
	function callOnHScripts(event:String, ?args:Array<Dynamic>, ?vars:Map<String, Dynamic>, ignoreStops = false, ?exclusions:Array<String>):Dynamic{
		if(FlxG.state == funkin.states.PlayState.instance)
            return funkin.states.PlayState.instance.callOnScripts(event, args, ignoreStops, exclusions, funkin.states.PlayState.instance.hscriptArray, vars);
        else
            return funkin.scripts.Globals.Function_Continue;

    }
	public function setHoldPos(x:Float, y:Float, column:Int = 0, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0){
		//sprTracker = daNote;


   //     xAdd = -Note.swagWidth * 0.95;
     //   yAdd = -Note.swagWidth + 14;

        	offsetX = x;
			offsetY = y;
			colorSwap.hue = hueColor;
			colorSwap.saturation = satColor;
			colorSwap.brightness = brtColor;
			if (genScript != null)
				{
					genScript.executeFunc("onUpdateColours", [this], this);
				}
			   /*if (sprTracker != null) {
				setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
				scrollFactor.set(sprTracker.scrollFactor.x, sprTracker.scrollFactor.y);
				}*/
	}
	public function reloadHold(textures:String = '')
		{
			if (genScript != null)
				genScript.executeFunc("onReloadHold", [this, textures], this);

			if (genScript != null && genScript.executeFunc("preReloadHold", [this, textures], this) == funkin.scripts.Globals.Function_Stop)
				return;
			var names = funkin.CoolUtil.capitalize(funkin.objects.Note.colArray[column]);
			if (Paths.imageExists(textures))
			frames = Paths.getSparrowAtlas(textures);
			else
			frames = Paths.getSparrowAtlas(textures + names);
			animation.addByPrefix('start', 'holdCoverStart' + names,24,false);
			animation.addByPrefix('covering', 'holdCover' + names + '0',24,true);
			animation.addByPrefix('end', 'holdCoverEnd' + names,24,false);
			animation.play('start');
			animation.finishCallback = function (name){
				if (name == 'start'){
					animation.play('covering',true);
                }
                if (name == 'end'){
                     visible = false;
                }
                };
				texture = textures;
				if (genScript != null)
					genScript.executeFunc("postReloadHold", [this, texture], this);
				scale.set(Note.spriteScale / 0.7,Note.spriteScale / 0.7);
				updateHitbox();
		}
		
	override function update(elapsed:Float) {
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				if (playHoldEnd){
				animation.play('end');
				}
				else 
				visible = false;
				resetAnim = 0;
				playHoldEnd = false;
				started = false;
			}
		}
		
		super.update(elapsed);
	}

}
