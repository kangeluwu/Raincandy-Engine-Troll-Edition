package funkin.states;

import flixel.addons.transition.FlxTransitionSprite.TransitionStatus;
import flixel.addons.transition.TransitionSubstate;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.util.FlxTimer;
import funkin.states.FadeTransitionSubstate;
import funkin.scripts.FunkinHScript;
class CustomTransitionSubstate extends FadeTransitionSubstate
{
	
	public var currentScript:FunkinHScript = null;
	public function createCustomTrans(name:String){
		var script = null;
		for (filePath in Paths.getFolders("transition"))
		{
			var fullPath = filePath + '$name.hscript';
			if (Paths.exists(fullPath)){
				script = FunkinHScript.fromFile(fullPath, fullPath, null, true);
				script.set('this',this);
				script.set('add',this.add);
				script.set('remove',this.remove);
				script.set('insert',this.insert);
				script.set('members',this.members);
				script.set('curStatus',this.curStatus);
				script.set('_finalDelayTime',this._finalDelayTime);
				script.set('updateFunc',this.updateFunc);
				script.set('delayThenFinish',this.delayThenFinish);
				script.set('onFinish',this.onFinish);
				script.set('transType',MusicBeatState.transType);
				script.call('onTransitionCreate',[]);
				currentScript = script;
				break;
			}
		}
		return script;
	}

	public override function update(elapsed:Float)
	{
		if (currentScript != null) currentScript.call('onUpdate',[elapsed]);
		super.update(elapsed);
		if (currentScript != null) currentScript.call('onUpdatePost',[elapsed]);
	}

	public override function draw()
	{
		if (currentScript != null) currentScript.call('onDraw',[]);
		super.draw();
		if (currentScript != null) currentScript.call('onDrawPost',[]);
	}

	override function createTransIn(status,cam){
		var scrippy = createCustomTrans(MusicBeatState.transType);
		if (scrippy == null)
		super.createTransIn(status,cam);
	}

	public override function destroy():Void
	{
		if (currentScript != null) currentScript.call('onDestroy',[]);
		super.destroy();
		currentScript = null;
	}
}