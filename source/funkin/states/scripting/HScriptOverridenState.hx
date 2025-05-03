#if SCRIPTABLE_STATES
package funkin.states.scripting;

class HScriptOverridenState extends HScriptedState 
{
	public var parentClass:Class<MusicBeatState> = null;

	override function _startExtensionScript(folder:String, scriptName:String,scriptPath:String)
		return;

	private function new(parentClass:Class<MusicBeatState>, scriptFullPath:String, args:Array<Dynamic> = null) 
	{
		if (parentClass == null || scriptFullPath == null) {
			trace("Uh oh!", parentClass, scriptFullPath);
			return;
		}

		this.parentClass = parentClass;
		
		super(scriptFullPath, [getShortClassName(parentClass) => parentClass], args);
	}

	static public function findClassOverride(cl:Class<MusicBeatState>, args:Array<Dynamic> = null):Null<HScriptOverridenState> 
	{
		var fullName = Type.getClassName(cl);
		for (filePath in Paths.getFolders("states"))
		{
			var folderedName = 'override/${fullName.split(".").join("/")}';
			var fileName = 'override/$fullName'; // deprecated
			var className = 'override/${getShortClassName(cl)}';
			for(ext in Paths.HSCRIPT_EXTENSIONS){
				var fullPath = filePath + fileName + '.$ext';
				var fullFolderPath = filePath + folderedName + '.$ext';
				var altPath = filePath + className + '.$ext';
				// TODO: Trim off the funkin.states and check that, too.
				
				if (Paths.exists(fullFolderPath))
					return new HScriptOverridenState(cl, fullFolderPath, args);
				else if (Paths.exists(fullPath))
					return new HScriptOverridenState(cl, fullPath, args);
				else if (Paths.exists(altPath))
					return new HScriptOverridenState(cl, altPath, args);
			}
		}


		return null;
	}

	static public function requestOverride(state:MusicBeatState, args:Array<Dynamic> = null):Null<HScriptOverridenState>
	{
		if (state != null && state.canBeScripted)
			return findClassOverride(Type.getClass(state), args);
		
		return null;
	}

	static public function fromAnother(state:HScriptOverridenState):Null<HScriptOverridenState>
	{
		return Paths.exists(state.scriptPath) ? new HScriptOverridenState(state.parentClass, state.scriptPath) : null;
	}

	inline private static function getShortClassName(cl):String
		return Type.getClassName(cl).split('.').pop();
}
#end