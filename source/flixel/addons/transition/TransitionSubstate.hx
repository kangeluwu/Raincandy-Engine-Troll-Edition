package flixel.addons.transition;

import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionSprite.TransitionStatus;
import flixel.FlxCamera;
class TransitionSubstate extends FlxSubState
{
	public var finishCallback:Void->Void;
	public static var defaultCamera:FlxCamera;
	public static var nextCamera:FlxCamera;

	public override function destroy():Void
	{
		super.destroy();
		finishCallback = null;
	}

	public function start(status: TransitionStatus){
		trace('transitioning $status');
	}
}
