package funkin.states.scripting;

import funkin.scripts.FunkinHScript;

class HScriptedSubstate extends MusicBeatSubstate
{
	public var scriptPath:String;

	public function new(scriptFullPath:String, ?scriptVars:Map<String, Dynamic>, args:Array<Dynamic> = null)
	{
		super();

		scriptPath = scriptFullPath;
		if (args == null){
			args = [];
		}
		var vars = _getScriptDefaultVars();

		if (scriptVars != null) {
			for (k => v in scriptVars)
				vars[k] = v;
		}

		_extensionScript = FunkinHScript.fromFile(scriptPath, scriptPath, vars, false);
		_extensionScript.call("new", args);
		_extensionScript.set("add", this.add);
		_extensionScript.set("remove", this.remove);
		_extensionScript.set("insert", this.insert);
		_extensionScript.set("members", this.members);
	}

	static public function fromFile(name:String, ?scriptVars:Map<String, Dynamic>, args:Array<Dynamic> = null)
	{
		for (filePath in Paths.getFolders("substates"))
		{
			var fullPath = filePath + '$name.hscript';
			if (Paths.exists(fullPath))
				return new HScriptedSubstate(fullPath, scriptVars, args);
		}

		return null;
	}
	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
		{
			if (_extensionScript != null){
				_extensionScript.call('getEvent',[id,sender,data,params]);
			}
		}
}