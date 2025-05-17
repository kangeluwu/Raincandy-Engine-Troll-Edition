package funkin.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import funkin.scripts.FunkinHScript;
class CustomFadeTransition extends MusicBeatSubstate 
{
	public static var finishCallback:Void->Void;
	public static var nextCamera:FlxCamera;
	public static var defaultCamera:FlxCamera;
	var transBlack:FlxSprite;
	var transGradient:FlxSprite;
	var leTween:FlxTween = null;
	public static var vars:Map<String,Dynamic> = new Map<String,Dynamic>();
	private var isTransIn:Bool = false;
	private var duration:Float = 0.6;
	public var transType:String = 'Normal';
	public var wasScripted:Bool = false;


	public function createCustomTrans(name:String){
		var script = null;
		for (filePath in Paths.getFolders("transition"))
		{
			var fullPath = filePath + '$name.hscript';
			if (Paths.exists(fullPath)){
				script = FunkinHScript.fromFile(fullPath, fullPath, vars, true);
				script.set('this',this);
				script.set('add',this.add);
				script.set('remove',this.remove);
				script.set('insert',this.insert);
				script.set('members',this.members);
				script.set('isTransIn',this.isTransIn);
				script.set('duration',this.duration);
				script.set('leTween',this.leTween);
				script.set('transType',this.transType);
				break;
			}
		}
		return script;
	}
	public function new(duration:Float, isTransIn:Bool, transType:String = 'Normal') 
	{
		super();
		this.duration = duration;
		this.isTransIn = isTransIn;
		this.transType = transType;
	}

	override public function create()
	{
		fade(isTransIn);
	}
	public function fade(transIn:Bool = false){
			switch (transType){
			default:
				var scrippy = createCustomTrans(transType);
				wasScripted = (scrippy != null);
				if (!wasScripted){
				var zoom:Float = CoolUtil.boundTo(FlxG.camera.zoom, 0.05, 1);
				var width:Int = Std.int(FlxG.width / zoom);
				var height:Int = Std.int(FlxG.height / zoom);

				transGradient = FlxGradient.createGradientFlxSprite(width, height, (transIn ? [0x0, FlxColor.BLACK] : [FlxColor.BLACK, 0x0]));
				transGradient.scrollFactor.set();
				add(transGradient);

				transBlack = new FlxSprite().makeGraphic(width, height + 400, FlxColor.BLACK);
				transBlack.scrollFactor.set();
				add(transBlack);

				transGradient.x -= (width - FlxG.width)* 0.5;
				transBlack.x = transGradient.x;

				if(transIn) {
					transGradient.y = transBlack.y - transBlack.height;
					FlxTween.tween(transGradient, {y: transGradient.height + 50}, duration, {
						onComplete: function(twn:FlxTween) {
							close();
						},
					ease: FlxEase.linear});
				} else {
					transGradient.y = -transGradient.height;
					transBlack.y = transGradient.y - transBlack.height + 50;
					leTween = FlxTween.tween(transGradient, {y: transGradient.height + 50}, duration, {
						onComplete: function(twn:FlxTween) {
							if(finishCallback != null) {
								finishCallback();
							}
						},
					ease: FlxEase.linear});
				}

				if(nextCamera != null) {
					transBlack.cameras = [nextCamera];
					transGradient.cameras = [nextCamera];
				}
				nextCamera = null;		
			}
		}
	}
	override function update(elapsed:Float) {
		switch (transType){
			default:
			if (!wasScripted){
			if (isTransIn)
				transBlack.y = transGradient.y + transGradient.height;
			else 
				transBlack.y = transGradient.y - transBlack.height;
			}
		}
		super.update(elapsed);
	}

	override function destroy() {
			if (!wasScripted){
			if(leTween != null) {
				finishCallback();
				leTween.cancel();
			}
		}
		super.destroy();
	}
}