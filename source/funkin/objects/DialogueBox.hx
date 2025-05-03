package funkin.objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.text.FlxTypeText;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.input.FlxKeyManager;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.scripts.*;
import funkin.states.*;
using StringTools;

class DialogueBox extends FlxSpriteGroup
{
	public var textSound:String = 'clickText';
	var box:FlxSprite;
	public var dialogueScripts:Array<FunkinScript> = [];
	var curCharacter:String = '';
	var dialogue:Alphabet;
	var dialogueList:Array<String> = [];
	public var scriptName:String = 'dialogue';
	// SECOND DIALOGUE FOR THE PIXEL SHIT INSTEAD???
	var swagDialogue:FlxTypeText;

	var dropText:FlxText;

	public var finishThing:Void->Void;
	public var nextDialogueThing:Void->Void = null;
	public var skipDialogueThing:Void->Void = null;

	var portraitLeft:FlxSprite;
	var portraitRight:FlxSprite;

	var handSelect:FlxSprite;
	var bgFade:FlxSprite;

	
	override function destroy()
		{
			for(script in dialogueScripts)
				removeScript(script, true);
			
			return super.destroy();
		}
	
		public function pushScript(script:FunkinScript, alreadyStarted:Bool=false){
			dialogueScripts.push(script);
			if(!alreadyStarted)
				startScript(script);
		}
	
		public function removeScript(script:FunkinScript, destroy:Bool = false, alreadyStopped:Bool = false)
		{
			dialogueScripts.remove(script);
			if (!alreadyStopped)
				stopScript(script, destroy);
		}
	
	
		public function startScript(script:FunkinScript){        
			#if HSCRIPT_ALLOWED
			if(script.scriptType == 'hscript'){
				callScript(script, "onLoad", [this]);
			}
			#end
		}
	
		public function stopScript(script:FunkinScript, destroy:Bool=false){
			#if HSCRIPT_ALLOWED
			if (script.scriptType == 'hscript'){
				callScript(script, "onStop", [this]);
				if(destroy){
					script.call("onDestroy");
					script.stop();
				}
			}
			#end
		}
		public var defaultVars:Map<String, Dynamic> = [];
		public function setDefaultVar(i:String, v:Dynamic)
			defaultVars.set(i, v);
		public function startScripts(paths:Array<String> = null)
			{
				if (paths == null)
					paths = Paths.getFolders("scripts/dialogue");
				setDefaultVar("this", this);
				setDefaultVar("dialogueTextSound", textSound);
				setDefaultVar("dialogueBox", box);
				setDefaultVar("dialogueChar", curCharacter);
				setDefaultVar("dialogueText", swagDialogue);
				setDefaultVar("dialogueDropText", dropText);
				setDefaultVar("dialogueList", dialogueList);
				setDefaultVar("dialoguePortraitLeft", portraitLeft);
				setDefaultVar("dialoguePortraitRight", portraitRight);
				setDefaultVar("handSelect", handSelect);
				setDefaultVar("dialogueBgFade", bgFade);
				for (path in paths){
				for (filePath in path)
				{
					for(ext in Paths.HSCRIPT_EXTENSIONS){
						var file = filePath + '$scriptName.${ext}';
						if (Paths.exists(file)){
							var script = FunkinHScript.fromFile(file, file, defaultVars);
							pushScript(script);
							return this;
						}
					}
					#if LUA_ALLOWED
		
					for (ext in Paths.LUA_EXTENSIONS) {
						var file = filePath + '$scriptName.${ext}';
						if (Paths.exists(file)){
							var script = FunkinLua.fromFile(file);
							pushScript(script);
							return this;
						}
					}
					#end
				}
			}
				return this;
			}
		
			public function callOnScripts(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>,
				?vars:Map<String, Dynamic>, ?ignoreSpecialShit:Bool = true):Dynamic
			{
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			if (args == null)
				args = [];
			if (scriptArray == null)
				scriptArray = dialogueScripts;
			if (exclusions == null)
				exclusions = [];
		
			var returnVal:Dynamic = Globals.Function_Continue;
			for (script in scriptArray)
			{
				if (exclusions.contains(script.scriptName))
					continue;
				
				var ret:Dynamic = script.call(event, args, vars);
				if (ret == Globals.Function_Halt)
				{
					ret = returnVal;
					if (!ignoreStops)
						return returnVal;
				};
				if (ret != Globals.Function_Continue && ret != null)
					returnVal = ret;
			}
		
			if (returnVal == null)
				returnVal = Globals.Function_Continue;
			return returnVal;
			#else
			return Globals.Function_Continue
			#end
			}
		
			public function setOnScripts(variable:String, value:Dynamic, ?scriptArray:Array<Dynamic>)
			{
			if (scriptArray == null)
				scriptArray = dialogueScripts;
		
			for (script in scriptArray)
			{
				script.set(variable, value);
				// trace('set $variable, $value, on ${script.scriptName}');
			}
			}
		
			public function callScript(script:Dynamic, event:String, ?args:Array<Dynamic>):Dynamic
			{
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED) // no point in calling this code if you.. for whatever reason, disabled scripting.
			if ((script is FunkinScript))
			{
				return callOnScripts(event, args, true, [], [script], [], false);
			}
			else if ((script is Array))
			{
				return callOnScripts(event, args, true, [], script, [], false);
			}
			else if ((script is String))
			{
				var scripts:Array<FunkinScript> = [];
		
				for (scr in dialogueScripts)
				{
					if (scr.scriptName == script)
						scripts.push(scr);
				}
		
				return callOnScripts(event, args, true, [], scripts, [], false);
			}
			#end
			return Globals.Function_Continue;
			}

	public function new(talkingRight:Bool = true, ?dialogueList:Array<String>,scriptNames:String = '',paths:Array<String> = null)
	{
		super();

		switch (PlayState.SONG.song.toLowerCase())
		{
			case 'senpai':
				FlxG.sound.playMusic(Paths.music('Lunchbox'), 0);
				FlxG.sound.music.fadeIn(1, 0, 0.8);
			case 'thorns':
				FlxG.sound.playMusic(Paths.music('LunchboxScary'), 0);
				FlxG.sound.music.fadeIn(1, 0, 0.8);
		}

		bgFade = new FlxSprite(-200, -200).makeGraphic(Std.int(FlxG.width * 1.3), Std.int(FlxG.height * 1.3), 0xFFB3DFd8);
		bgFade.scrollFactor.set();
		bgFade.alpha = 0;
		add(bgFade);

		new FlxTimer().start(0.83, function(tmr:FlxTimer)
		{
			bgFade.alpha += (1 / 5) * 0.7;
			if (bgFade.alpha > 0.7)
				bgFade.alpha = 0.7;
		}, 5);

		box = new FlxSprite(-20, 45);
		
		var hasDialog = false;
		switch (PlayState.SONG.song.toLowerCase())
		{
			case 'senpai':
				hasDialog = true;
				box.frames = Paths.getSparrowAtlas('pixelUI/dialogueBox-pixel');
				box.animation.addByPrefix('normalOpen', 'Text Box Appear', 24, false);
				box.animation.addByIndices('normal', 'Text Box Appear instance 1', [4], "", 24);
			case 'roses':
				hasDialog = true;
				FlxG.sound.play(Paths.sound('ANGRY_TEXT_BOX'));

				box.frames = Paths.getSparrowAtlas('pixelUI/dialogueBox-senpaiMad');
				box.animation.addByPrefix('normalOpen', 'SENPAI ANGRY IMPACT SPEECH', 24, false);
				box.animation.addByIndices('normal', 'SENPAI ANGRY IMPACT SPEECH instance 1', [4], "", 24);

			case 'thorns':
				hasDialog = true;
				box.frames = Paths.getSparrowAtlas('pixelUI/dialogueBox-evil');
				box.animation.addByPrefix('normalOpen', 'Spirit Textbox spawn', 24, false);
				box.animation.addByIndices('normal', 'Spirit Textbox spawn instance 1', [11], "", 24);

				var face:FlxSprite = new FlxSprite(320, 170).loadGraphic(Paths.image('weeb/spiritFaceForward'));
				face.setGraphicSize(Std.int(face.width * 6));
				add(face);
		}

		this.dialogueList = dialogueList;
		
		portraitLeft = new FlxSprite(-20, 40);
		portraitLeft.frames = Paths.getSparrowAtlas('weeb/senpaiPortrait');
		portraitLeft.animation.addByPrefix('enter', 'Senpai Portrait Enter', 24, false);
		portraitLeft.setGraphicSize(Std.int(portraitLeft.width * 6 * 0.9));
		portraitLeft.updateHitbox();
		portraitLeft.scrollFactor.set();
		add(portraitLeft);
		portraitLeft.visible = false;

		portraitRight = new FlxSprite(0, 40);
		portraitRight.frames = Paths.getSparrowAtlas('weeb/bfPortrait');
		portraitRight.animation.addByPrefix('enter', 'Boyfriend portrait enter', 24, false);
		portraitRight.setGraphicSize(Std.int(portraitRight.width * 6 * 0.9));
		portraitRight.updateHitbox();
		portraitRight.scrollFactor.set();
		add(portraitRight);
		portraitRight.visible = false;
		if (box.frames != null){
		box.animation.play('normalOpen');
		box.setGraphicSize(Std.int(box.width * 6 * 0.9));
		box.updateHitbox();
		box.cameras = [PlayState.instance.camOther];
		add(box);

		box.screenCenter(X);
		}
		portraitLeft.screenCenter(X);

		handSelect = new FlxSprite(1042, 590).loadGraphic(Paths.image('pixelUI/hand_textbox'));
		handSelect.setGraphicSize(Std.int(handSelect.width * 6 * 0.9));
		handSelect.updateHitbox();
		handSelect.visible = false;
		add(handSelect);


		if (!talkingRight)
		{
			// box.flipX = true;
		}

		dropText = new FlxText(242, 502, Std.int(FlxG.width * 0.6), "", 32);
		dropText.font = 'Pixel Arial 11 Bold';
		dropText.color = 0xFFD89494;
		add(dropText);

		swagDialogue = new FlxTypeText(240, 500, Std.int(FlxG.width * 0.6), "", 32);
		swagDialogue.font = 'Pixel Arial 11 Bold';
		swagDialogue.color = 0xFF3F2021;
		swagDialogue.sounds = [FlxG.sound.load(Paths.sound('pixelText'), 0.6)];
		add(swagDialogue);

		dialogue = new Alphabet(0, 80, "", false, true);
		// dialogue.x = 90;
		// add(dialogue);
		var songName = Paths.formatToSongPath(PlayState.SONG.song);
		if (scriptNames == '' || scriptNames == null)
			scriptNames = songName+'Dialogue';
		scriptName = scriptNames;

		if (paths == null){
			
			var s = Paths.getFolders('songs/$songName');
			for (folder in Paths.getFolders('data/$songName'))
				s.push(folder);
			for (folder in Paths.getFolders('scripts/dialogue'))
				s.push(folder);
			paths = s;
		}
		startScripts(paths);
		callOnScripts("onLoad", [box]);
	}

	var dialogueOpened:Bool = false;
	var dialogueStarted:Bool = false;
	var dialogueEnded:Bool = false;

	override function update(elapsed:Float)
	{
		if (callOnScripts("onDialogueUpdate", [elapsed]) == Globals.Function_Stop)
			return;

		// HARD CODING CUZ IM STUPDI
		if (PlayState.SONG.song.toLowerCase() == 'roses')
			portraitLeft.visible = false;
		if (PlayState.SONG.song.toLowerCase() == 'thorns')
		{
			portraitLeft.visible = false;
			swagDialogue.color = FlxColor.WHITE;
			dropText.color = FlxColor.BLACK;
		}

		dropText.text = swagDialogue.text;

		if (box.animation.curAnim != null)
		{
			if (box.animation.curAnim.name == 'normalOpen' && box.animation.curAnim.finished)
			{
				box.animation.play('normal');
				dialogueOpened = true;
				callOnScripts("onDialogueOpenFinished", [box]);
			}
		}

		if (dialogueOpened && !dialogueStarted)
		{
			startDialogue();
			dialogueStarted = true;
			
		}
		if(funkin.input.PlayerSettings.player1.controls.ACCEPT #if mobile || justTouched #end)
		{
			if (dialogueEnded)
			{
				if (callOnScripts("onDialoguePreEnded", [box]) == Globals.Function_Stop)
					return;
				remove(dialogue);
				if (dialogueList[1] == null && dialogueList[0] != null)
				{
					if (!isEnding)
					{
						if (callOnScripts("onDialoguePreFinished", [box]) == Globals.Function_Stop)
							return;
						isEnding = true;
						FlxG.sound.play(Paths.sound(textSound), 0.8);	

						if (PlayState.SONG.song.toLowerCase() == 'senpai' || PlayState.SONG.song.toLowerCase() == 'thorns')
							FlxG.sound.music.fadeOut(1.5, 0);

						var fadeTimer = new FlxTimer().start(0.2, function(tmr:FlxTimer)
						{
							box.alpha -= 1 / 5;
							bgFade.alpha -= 1 / 5 * 0.7;
							portraitLeft.visible = false;
							portraitRight.visible = false;
							swagDialogue.alpha -= 1 / 5;
							handSelect.alpha -= 1 / 5;
							dropText.alpha = swagDialogue.alpha;
						}, 5);

						var killTimer = new FlxTimer().start(1.5, function(tmr:FlxTimer)
						{
							finishThing();
							kill();
						});
						callOnScripts("onDialogueFinished", [box,fadeTimer,killTimer]);
					}
				}
				else
				{
					if (callOnScripts("onDialoguePreRemovedText", [box]) == Globals.Function_Stop)
						return;
			
					dialogueList.remove(dialogueList[0]);
					startDialogue();
					FlxG.sound.play(Paths.sound(textSound), 0.8);
					callOnScripts("onDialogueRemovedText", [box]);
				}
				callOnScripts("onDialogueEnded", [box]);
			}
			else if (dialogueStarted)
			{
				if (callOnScripts("onDialoguePreSkiped", [box]) == Globals.Function_Stop)
					return;
				FlxG.sound.play(Paths.sound(textSound), 0.8);
				swagDialogue.skip();
				callOnScripts("onDialogueSkiped", [box]);
				if(skipDialogueThing != null) {
					skipDialogueThing();
				}
			}
		}
		
		super.update(elapsed);
		callOnScripts("onDialogueUpdatePost", [elapsed]);
	}

	var isEnding:Bool = false;

	function startDialogue():Void
	{
		if (callOnScripts("onDialoguePreStarted", [box]) == Globals.Function_Stop)
			return;
		cleanDialog();
		// var theDialog:Alphabet = new Alphabet(0, 70, dialogueList[0], false, true);
		// dialogue = theDialog;
		// add(theDialog);

		// swagDialogue.text = ;
		swagDialogue.resetText(dialogueList[0]);
		swagDialogue.start(0.04, true);
		swagDialogue.completeCallback = function() {
			handSelect.visible = true;
			dialogueEnded = true;
		};

		handSelect.visible = false;
		dialogueEnded = false;
		switch (curCharacter)
		{
			case 'dad':
				portraitRight.visible = false;
				if (!portraitLeft.visible)
				{
					if (PlayState.SONG.song.toLowerCase() == 'senpai') portraitLeft.visible = true;
					portraitLeft.animation.play('enter');
				}
			case 'bf':
				portraitLeft.visible = false;
				if (!portraitRight.visible)
				{
					portraitRight.visible = true;
					portraitRight.animation.play('enter');
				}
		}
		callOnScripts("onDialogueStared", [box,swagDialogue]);
		if(nextDialogueThing != null) {
			nextDialogueThing();
		}
		
	}

	function cleanDialog():Void
	{
		var splitName:Array<String> = dialogueList[0].split(":");
		curCharacter = splitName[1];
		dialogueList[0] = dialogueList[0].substr(splitName[1].length + 2).trim();
	}
}
