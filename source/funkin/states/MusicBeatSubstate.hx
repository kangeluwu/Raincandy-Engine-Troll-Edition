package funkin.states;

import funkin.scripts.FunkinHScript;
import funkin.input.Controls;
import flixel.FlxSubState;
import flixel.addons.ui.*;
import flixel.addons.display.FlxRuntimeShader;
import flixel.util.FlxSort;
@:autoBuild(funkin.macros.ScriptingMacro.addScriptingCallbacks([
	"create",
	"update",
	"destroy",
	"close",
	"openSubState",
	"closeSubState",
	"stepHit",
	"beatHit"
], "substates"))
class MusicBeatSubstate extends FlxUISubState
{
	public var canBeScripted(get, default):Bool = true;
	@:noCompletion function get_canBeScripted() return canBeScripted;

	//// To be defined by the scripting macro
	@:noCompletion public var _extensionScript:FunkinHScript;

	@:noCompletion public function _getScriptDefaultVars() 
		return new Map<String, Dynamic>();

	@:noCompletion public function _startExtensionScript(folder:String, scriptName:String,scriptPath:String)
		return;

	////
	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	private var controls(get, never):Controls;

	inline function get_controls():Controls
		return funkin.input.PlayerSettings.player1.controls;

	public function refresh()
		{
		  sort(funkin.CoolUtil.byZIndex, FlxSort.ASCENDING);
		}
		
	override function update(elapsed:Float)
	{		
		updateSteps();

		super.update(elapsed);
	}
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	public function createRuntimeShader(name:String,?glslVersion:Int = 120):FlxRuntimeShader
		{
	
			#if (MODS_ALLOWED && sys)
			if(!runtimeShaders.exists(name) && !initShader(name))
			{
				FlxG.log.warn('Shader $name is missing!');
				return new FlxRuntimeShader();
			}
	
			var arr:Array<String> = runtimeShaders.get(name);
			return Paths.getShader(arr[0], arr[1],glslVersion);
			#else
			FlxG.log.warn("Platform unsupported for Runtime Shaders!");
			return null;
			#end
		}
	public function initShader(name:String)
	{

		if(runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		var frag:String = Paths.getShaderFragment(name);
		var vert:String = Paths.getShaderVertex(name);
		var found:Bool = false;
		if(frag != null)
		{
			found = true;
		}

		if (vert != null)
		{
			found = true;
		}

		if(found)
		{
			runtimeShaders.set(name, [frag, vert]);
			//trace('Found shader $name!');
			return true;
		}

		FlxG.log.warn('Missing shader $name .frag AND .vert files!');
		return false;
	}
	private function updateSteps() {
		var oldStep:Int = curStep;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
			stepHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public function stepHit():Void
	{
		if (curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void
	{
		//do literally nothing dumbass
	}
}
