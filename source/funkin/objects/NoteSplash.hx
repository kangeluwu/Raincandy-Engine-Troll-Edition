package funkin.objects;

import funkin.states.PlayState;
import funkin.scripts.Globals;
import math.Vector3;
import flixel.FlxG;
import funkin.objects.shaders.ColorSwap;
import flixel.system.FlxAssets.FlxShader;
import flixel.math.FlxMath;
import flixel.graphics.frames.FlxFrame;
typedef NoteSplashConfig = {
	anim:String,
	minFps:Int,
	maxFps:Int,
	offsets:Array<Array<Float>>
}
class NoteSplash extends NoteObject
{
	private var idleAnim:String;
	private var textureLoaded:String = null;
	private var configLoaded:String = null;
	public var vec3Cache:Vector3 = new Vector3();

	public static var defaultNoteSplash(default, never):String = 'noteSplashes';
	public static var configs:Map<String, NoteSplashConfig> = new Map<String, NoteSplashConfig>();
	public function new(x:Float = 0, y:Float = 0, ?note:Int = 0) {
		super(x, y);
		objType = SPLASH;
		
		colorSwap = new ColorSwap();
		shader = colorSwap.shader;

		var skin:String = null;
		if(PlayState.splashSkin != null && PlayState.splashSkin.length > 0) skin = PlayState.splashSkin;
		else skin = defaultNoteSplash;

		precacheConfig(skin);
		configLoaded = skin;
		scrollFactor.set();
		//loadAnims(PlayState.splashSkin);
		//setupNoteSplash(x, y, note);
        visible = false;
	}

	function callOnHScripts(event:String, ?args:Array<Dynamic>, ?vars:Map<String, Dynamic>, ignoreStops = false, ?exclusions:Array<String>):Dynamic{
		if(FlxG.state == PlayState.instance)
            return PlayState.instance.callOnScripts(event, args, ignoreStops, exclusions, PlayState.instance.hscriptArray, vars);
        else
            return Globals.Function_Continue;

    }
    
	override function destroy()
		{
			configs.clear();
			super.destroy();
		}

	public var animationAmount:Int = 2;
	public function setupNoteSplash(x:Float, y:Float, column:Int = 0, texture:String = null, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0, ?note:Note) 
	{
		visible = true;
        var doR:Bool = false;
		if (note != null && note.genScript != null){
            var ret:Dynamic = note.genScript.call("preSetupNoteSplash", [x, y, column, texture, hueColor, satColor, brtColor, note], ["this" => this, "noteData" => noteData, "column" => column]);
            if(ret == Globals.Function_Stop) doR = true;
        }
        
		if (callOnHScripts("preSetupNoteSplash", [x, y, column, texture, hueColor, satColor, brtColor, note], ["this" => this, "noteData" => noteData, "column" => column]) == Globals.Function_Stop)
            return;

		if (doR)return;
		
		aliveTime = 0;
		setPosition(x, y);
		animationAmount = 2;
		alpha = 0.6;
		scale.set(0.8 * Note.spriteScale / 0.7, 0.8 * Note.spriteScale / 0.7);
		updateHitbox();
		offsetX = 0;
		offsetY = 0;
		this.column = column;
		if (texture == null) texture = PlayState.splashSkin;
		if (texture == null || texture.length < 1)
			texture = defaultNoteSplash;
        if(note != null && note.genScript != null){
			if (note.genScript.exists("texturePrefix")) texture = note.genScript.get("texturePrefix") + texture;

            if (note.genScript.exists("textureSuffix")) texture += note.genScript.get("textureSuffix");
        }

		var config:NoteSplashConfig = null;
		if (textureLoaded != texture) {
			var ret = Globals.Function_Continue;

            if (note != null && note.genScript != null)
				ret = note.genScript.call("loadSplashAnims", [texture], ["this" => this, "noteData" => noteData, "column" => column]);

			ret = callOnHScripts("loadSplashAnims", [texture], ["this" => this, "noteData" => noteData, "column" => column]);

			if (ret != Globals.Function_Stop) 
				config = loadAnims(texture);
		}else
			config = precacheConfig(configLoaded);

		colorSwap.hue = hueColor;
		colorSwap.saturation = satColor;
		colorSwap.brightness = brtColor;

		var ret = Globals.Function_Continue;
		if (note != null && note.genScript != null)
			ret = note.genScript.call("postSetupNoteSplash", [x, y, column, texture, hueColor, satColor, brtColor, note], ["this" => this, "noteData" => noteData, "column" => column]);
		
		ret = callOnHScripts("postSetupNoteSplash", [x, y, column, texture, hueColor, satColor, brtColor, note], ["this" => this, "noteData" => noteData, "column" => column]);

		if (ret != Globals.Function_Stop){
			

		var playAnim = 'note$column';	
		var animNum:Int = FlxG.random.int(1, animationAmount);
		if (animationAmount > 1) playAnim += '-'+animNum;
		animation.play(playAnim, true);
		
		var minFps:Int = 22;
		var maxFps:Int = 26;
		if(config != null)
		{
			var target = (animNum - 1);
			var animID:Int = column + (target * Note.colArray.length);
			//trace('anim: ${animation.curAnim.name}, $animID');
			var offs:Array<Float> = config.offsets[FlxMath.wrap(animID, 0, config.offsets.length-1)];
			offsetX -= offs[0];
			offsetY -= offs[1];
			minFps = config.minFps;
			maxFps = config.maxFps;
		}

		if (animation.curAnim != null) animation.curAnim.frameRate = 24 + FlxG.random.int(-2, 2);
		}
	}

	function loadAnims(skin:String, ?animName:String = null) {
		textureLoaded = skin;
		animationAmount = 0;
		frames = Paths.getSparrowAtlas(skin);
		var config:NoteSplashConfig = null;
		if(frames == null)
		{
			skin = defaultNoteSplash;
			frames = Paths.getSparrowAtlas(skin);
			if(frames == null) //if you really need this, you really fucked something up
			{
				skin = defaultNoteSplash;
				frames = Paths.getSparrowAtlas(skin);
			}
		}
		config = precacheConfig(skin);
		configLoaded = skin;

		
		if(animName == null)
			animName = config != null ? config.anim : 'note splash';
		/*for (i in 1...animationAmount+1)
		{
			animation.addByPrefix("note0-" + i, "note splash purple " + i, 24, false);
			animation.addByPrefix("note1-" + i, "note splash blue " + i, 24, false);
			animation.addByPrefix("note2-" + i, "note splash green " + i, 24, false);
			animation.addByPrefix("note3-" + i, "note splash red " + i, 24, false);
		}*/
		while(true) {
			var animID:Int = animationAmount + 1;
			for (i in 0...Note.colArray.length) {
				if (!addAnimAndCheck('note$i-$animID', '$animName ${Note.colArray[i]} $animID', 24, false)) {
					//trace('maxAnims: $maxAnims');
					return config;
				}
			}
			animationAmount++;
			//trace('currently: $maxAnims');
		}
	}

	
	public static function precacheConfig(skin:String)
		{
			if(configs.exists(skin)) return configs.get(skin);
	
			var path:String = Paths.getPath('images/$skin.txt', true);
			var configFile:Array<String> = funkin.CoolUtil.coolTextFile(path);
			if(configFile.length < 1) return null;
			
			var framerates:Array<String> = configFile[1].split(' ');
			var offs:Array<Array<Float>> = [];
			for (i in 2...configFile.length)
			{
				var animOffs:Array<String> = configFile[i].split(' ');
				offs.push([Std.parseFloat(animOffs[0]), Std.parseFloat(animOffs[1])]);
			}
	
			var config:NoteSplashConfig = {
				anim: configFile[0],
				minFps: Std.parseInt(framerates[0]),
				maxFps: Std.parseInt(framerates[1]),
				offsets: offs
			};
			configs.set(skin, config);
			return config;
		}

		
	function addAnimAndCheck(name:String, anim:String, ?framerate:Int = 24, ?loop:Bool = false)
		{
			animation.addByPrefix(name, anim, framerate, loop);
			return animation.getByName(name) != null;
		}
	static var aliveTime:Float = 0;
	static var buggedKillTime:Float = 0.5; //automatically kills note splashes if they break to prevent it from flooding your HUD
	override function update(elapsed:Float) {
		aliveTime += elapsed;
		if((animation.curAnim != null && animation.curAnim.finished) ||
			(animation.curAnim == null && aliveTime >= buggedKillTime)) kill();

		super.update(elapsed);
	}
}
	