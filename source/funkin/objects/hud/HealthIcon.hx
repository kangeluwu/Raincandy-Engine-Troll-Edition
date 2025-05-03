package funkin.objects.hud;

import flixel.graphics.FlxGraphic;
import flixel.FlxSprite;
import flixel.addons.display.FlxRuntimeShader;
import flixel.graphics.frames.FlxAtlasFrames;
using StringTools;
import flixel.math.FlxPoint;
import flixel.math.FlxPoint.FlxBasePoint;
enum abstract IconState(Int) from Int to Int {
	var Normal;
	var Dying;
	var Winning;
}
class HealthIcon extends FlxSprite
{
	public var isAnimated:Bool = false;
	public var isPlayState:Bool = (flixel.FlxG.state is PlayState && flixel.FlxG.state == PlayState.instance);
	public var sprTracker:FlxObject;
	private var isOldIcon:Bool = false;
	private var isPlayer:Bool = false;
	private var char:String = '';
	var nameAnimate:String = 'normal';
	public var iconState(default, set):IconState = Normal;
	function set_iconState(x:IconState):IconState {
		if (isAnimated){
			switch (x) {
			case Normal:
				nameAnimate = 'normal';
			case Dying:
				// if we set it out of bounds it doesn't realy matter as it goes to normal anyway
				nameAnimate = 'dying';
			case Winning:
				// we DO do it here here we want to make sure it isn't silly
				if (animation.exists('winning'))
				nameAnimate = 'winning';
				else
				nameAnimate = 'normal';
			}
		}else{
				switch (x) {
			case Normal:
				animation.curAnim.curFrame = 0;
			case Dying:
				// if we set it out of bounds it doesn't realy matter as it goes to normal anyway
				animation.curAnim.curFrame = 1;
			case Winning:
				// we DO do it here here we want to make sure it isn't silly
				if (animation.curAnim.frames.length >= 3) {
					animation.curAnim.curFrame = 2;
				} else {
					animation.curAnim.curFrame = 0;
				}
			}
			}
		
		return iconState = x;
	}
	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();
		this.isPlayer = isPlayer;

		changeIcon(char);
		
	}
	override function initVars():Void
	{
		super.initVars();
	}

	override function update(elapsed:Float)
	{
		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
	
		if (isAnimated)
			animation.play(nameAnimate);
	
		super.update(elapsed);
		
	}

	function changeIconGraphic(graphic:FlxGraphic,w:Null<Float> = -1,h:Null<Float> = -1,f:Array<Int> = null)
	{
		if (f == null || f.length <= 0)
			f = [0, 1];
		if (w <= 0)
			w = graphic.width * 0.5;
		if (h <= 0)
			h = graphic.height;
		loadGraphic(graphic, true,Math.floor(w), Math.floor(h));
		iconOffsets[0] = (width - 150) * 0.5;
		iconOffsets[1] = (width - 150) * 0.5;
		updateHitbox();

		animation.add(char, f, 0, false, isPlayer);
		animation.play(char);
	}

	function changeIconAnim(framess:FlxAtlasFrames,animNames:Array<String> = null)
		{
			if (animNames == null || animNames.length <= 0)
				animNames = ['normal', 'dying'];
					frames = framess;
					animation.addByPrefix('normal', animNames[0], 24, true, isPlayer);
					animation.addByPrefix('dying', animNames[1], 24, true, isPlayer);
					if (animNames.length > 2)
					animation.addByPrefix('winning', animNames[2], 24, true, isPlayer);
                    animation.play(nameAnimate);
		}

		
	public function swapOldIcon() 
	{
		if (!isOldIcon){
			var oldIcon = Paths.image('icons/$char-old');
			
			if(oldIcon == null)
				oldIcon = Paths.image('icons/icon-$char-old'); // base game compat

			if (oldIcon != null){
				changeIconGraphic(oldIcon);
				isOldIcon = true;
				return;
			}
		}

		changeIcon(char);
		isOldIcon = false;
	}
	private var iconOffsetsAlt:Array<Float> = [0, 0];
	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String) {
/* 		var file:Null<FlxGraphic> = Paths.image('characters/icons/$char'); // i'd like to use this some day lol

		if (file == null)
			file = Paths.image('icons/$char'); // new psych compat */

		var iconScale:Array<Float> = [1, 1];
		var iconFrames:Array<Int> = [];
		var iconString:Array<String> = [];
		var iconWidth:Null<Float> = -1;
		var iconHeight:Null<Float> = -1;
		
		var folders = Paths.getFolders('images/icons');
		for (folder in folders){
			var path = folder + 'icons.json';
			if (Paths.exists(path))
				{
					var json = Paths.getJson(path);
					if (Reflect.hasField(json, char)){
						var data = Reflect.field(json, char);
						if (Reflect.hasField(data, 'frames') && Reflect.field(data, 'frames').length > 1){
							iconFrames = Reflect.field(data, 'frames');
						}
						if (Reflect.hasField(data, 'frameNames') && Reflect.field(data, 'frameNames').length > 1){
							iconString = Reflect.field(data, 'frameNames');
						}
						if (Reflect.hasField(data, 'width')){
							iconWidth = Reflect.field(data, 'width');
						}
						if (Reflect.hasField(data, 'height')){
							iconHeight = Reflect.field(data, 'height');
						}
						if (Reflect.hasField(data, 'offsets')){
							iconOffsetsAlt = Reflect.field(data, 'offsets');
						}
					
					}
				}
		}
	
		var file:Null<FlxGraphic> = Paths.image('icons/$char'); 

		if(file == null)
			file = Paths.image('icons/icon-$char'); // base game compat
		
		if(file == null) 
			file = Paths.image('icons/face'); // Prevents crash from missing icon
		var anim:Null<FlxAtlasFrames> = null; 
		if (Paths.exists(Paths.getPath('images/icons/$char.xml')))
			anim = Paths.getSparrowAtlas('icons/$char');
		else if (Paths.exists(Paths.getPath('images/icons/icon-$char.xml')))
			anim = Paths.getSparrowAtlas('icons/icon-$char'); 
		else if (Paths.exists(Paths.getPath('images/icons/face.xml')))
			anim = Paths.getSparrowAtlas('icons/face'); 

		if (anim != null){
			changeIconAnim(anim,iconString);
			this.char = char;
			isAnimated = true;
		}
		else if (file != null){
			//// TODO: sparrow atlas icons? would make the implementation of extra behaviour (ex: winning icons) way easier
			changeIconGraphic(file,iconWidth,iconHeight,iconFrames);
			this.char = char;
			isAnimated = false;
		}

		if (char.endsWith("-pixel")){
			antialiasing = false;
			useDefaultAntialiasing = false;
		}
	}

	override function updateHitbox()
	{
		super.updateHitbox();
		if (isPlayState){
			offset.x = iconOffsets[0] + (isPlayer ? iconOffsetsAlt[0] : iconOffsetsAlt[2]);
			offset.y = iconOffsets[1] + iconOffsetsAlt[1];
			}
			else
			{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
			}
	}

	public function getCharacter():String {
		return char;
	}
}