package funkin.objects;

import flixel.math.FlxMath;
import funkin.states.PlayState;
import funkin.data.JudgmentManager.Judgment;
import funkin.states.editors.ChartingState;
import math.Vector3;
import funkin.scripts.*;
import funkin.objects.playfields.*;
import funkin.objects.shaders.ColorSwap;

using StringTools;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String,
	value3:String
}

typedef HitResult = {
	judgment: Judgment,
	hitDiff: Float
}

enum abstract SplashBehaviour(Int) from Int to Int
{
	/**Only splashes on judgements that have splashes**/
	var DEFAULT = 0;
	/**Never splashes**/
	var DISABLED = -1;
	/**Always splashes**/
	var FORCED = 1;
}

enum abstract SustainPart(Int) from Int to Int
{
	var TAP = -1; // Not a sustain
    var HEAD = 0; // TapNote at the start of a sustain
	var PART = 1;
	var END = 2;
}
typedef NoteDataFile =
{
	var defaultData:NoteData;
	@:optional var datas:Array<NoteData>;
}
typedef NoteData ={
	var color:Array<String>;
	@:optional var pixelTarget:Array<Int>;
	var amountUsed:Int;
	@:optional var strumAnimations:StrumData;
}
typedef StrumData ={
	@:optional var staticAnimNames :Array<String>;
	@:optional var pressAnimNames  :Array<String>;
	@:optional var confirmAnimNames  :Array<String>;
}
class Note extends NoteObject
{
	public var holdGlow:Bool = true; // Whether holds should "glow" / increase in alpha when held
	public var baseAlpha:Float = 1;

	public static var spriteScale:Float = 0.7;
	public static var swagWidth(default, set):Float = 160 * spriteScale;
	public static var halfWidth(default, null):Float = swagWidth * 0.5;
	public static var NOTE_AMOUNT:Int = PlayState.keyCount;
	public static var colorData:NoteDataFile = {
		defaultData:{
		color:['purple', 'blue', 'green', 'red'],
		strumAnimations:{
			staticAnimNames:['arrowLEFT', 'arrowDOWN', 'arrowUP', 'arrowRIGHT'],
			pressAnimNames:["left press", "down press", "up press", "right press"],
			confirmAnimNames:["left confirm", "down confirm", "up confirm", "right confirm"],
		},
		amountUsed:4,
		pixelTarget:[0,1,2,3]
	},
		datas:[
			{
				color:['green'],
				amountUsed:4,
				pixelTarget:[2],
				strumAnimations:{
					staticAnimNames:['arrowUP'],
					pressAnimNames:["up press"],
					confirmAnimNames:["up confirm"],
				}
			},
			{
				color:['purple', 'red'],
				amountUsed:4,
				pixelTarget:[0,3],
				strumAnimations:{
					staticAnimNames:['arrowLEFT','arrowRIGHT'],
					pressAnimNames:["left press","right press"],
					confirmAnimNames:["left confirm", "right confirm"],
				}
			},
			{
				color:['purple', 'blue', 'red'],
				amountUsed:4,
				pixelTarget:[0,1,3],
				strumAnimations:{
					staticAnimNames:['arrowLEFT','arrowDOWN','arrowRIGHT'],
					pressAnimNames:["left press","down press","right press"],
					confirmAnimNames:["left confirm", "down confirm", "right confirm"],
				}
			},
			{
				color:['purple', 'blue', 'green', 'red'],
				amountUsed:4,
				strumAnimations:{
					staticAnimNames:['arrowLEFT', 'arrowDOWN', 'arrowUP', 'arrowRIGHT'],
					pressAnimNames:["left press", "down press", "up press", "right press"],
					confirmAnimNames:["left confirm", "down confirm", "up confirm", "right confirm"],
				},
				pixelTarget:[0,1,2,3]
			},
			{
				color:['purple', 'blue', 'green', 'blue', 'red'],
				amountUsed:4,
				strumAnimations:{
					staticAnimNames:['arrowLEFT', 'arrowDOWN', 'arrowUP', 'arrowDOWN', 'arrowRIGHT'],
					pressAnimNames:["left press", "down press", "up press", "down press", "right press"],
					confirmAnimNames:["left confirm", "down confirm", "up confirm", "down confirm", "right confirm"],
				},
				pixelTarget:[0,1,2,1,3]
			},
			{
				color:['purple', 'green', 'red', 'purple', 'blue', 'red'],
				amountUsed:4,
				strumAnimations:{
					staticAnimNames:['arrowLEFT', 'arrowDOWN', 'arrowRIGHT', 'arrowLEFT', 'arrowUP', 'arrowRIGHT'],
					pressAnimNames:["left press", "down press", "right press", "left press", "up press", "right press"],
					confirmAnimNames:["left confirm", "down confirm", "right confirm", "left confirm", "up confirm", "right confirm"],
				},
				pixelTarget:[0,2,3,0,1,3]
			},
			{
				color:['purple', 'blue', 'red', 'green', 'purple', 'blue', 'red'],
				amountUsed:4,
				pixelTarget:[0,1,3,2,0,1,3]
			},
			{
				color:['purple', 'blue', 'green', 'red', 'purple', 'blue', 'green', 'red'],
				amountUsed:4,
				pixelTarget:[0,1,2,3,0,1,2,3]
			},
			{
				color:['purple', 'green', 'red', 'purple', 'blue', 'red'],
				amountUsed:4,
				pixelTarget:[0,2,3,0,1,3]
			},
			{
				color:['purple', 'green', 'red', 'purple', 'blue', 'red'],
				amountUsed:4,
				pixelTarget:[0,2,3,0,1,3]
			}
	]
	};

	public static var defaultColorData:NoteDataFile = {
		defaultData:{
		color:['purple', 'blue', 'green', 'red'],
		amountUsed:4,
		pixelTarget:[0,1,2,3]
	},
		datas:[
			{
				color:['purple'],
				amountUsed:4,
				pixelTarget:[0]
			},
			{
				color:['purple', 'green'],
				amountUsed:4,
				pixelTarget:[0,2]
			},
			{
				color:['purple', 'blue', 'red'],
				amountUsed:4,
				pixelTarget:[0,1,3]
			},
			{
				color:['purple', 'blue', 'green', 'red'],
				amountUsed:4,
				pixelTarget:[0,1,2,3]
			},
			{
				color:['purple', 'blue', 'green', 'blue', 'red'],
				amountUsed:4,
				pixelTarget:[0,1,2,1,3]
			},
			{
				color:['purple', 'green', 'red', 'purple', 'blue', 'red'],
				amountUsed:4,
				pixelTarget:[0,2,3,0,1,3]
			},
			{
				color:['purple', 'blue', 'red', 'green', 'purple', 'blue', 'red'],
				amountUsed:4,
				pixelTarget:[0,1,3,2,0,1,3]
			},
			{
				color:['purple', 'blue', 'green', 'red', 'purple', 'blue', 'green', 'red'],
				amountUsed:4,
				pixelTarget:[0,1,2,3,0,1,2,3]
			}
	]
	};
	public static var pixelTarget:Array<Int> = colorData.defaultData.pixelTarget;
	public static var colArray:Array<String> = colorData.defaultData.color;
	public static var DATA_AMOUNT:Int = colorData.defaultData.amountUsed;
	public static var quants:Array<Int> = [
		4, // quarter note
		8, // eight
		12, // etc
		16,
		20,
		24,
		32,
		48,
		64,
		96,
		192
	];

	public static var defaultNotes = [
		'No Animation',
		'GF Sing',
		''
	];

	public static var quantShitCache = new Map<String, Null<String>>();

	public static function getQuant(beat:Float){
		var row:Int = Conductor.beatToNoteRow(beat);
		for(data in quants){
			if (row % (Conductor.ROWS_PER_MEASURE/data) == 0)
				return data;
		}
		return quants[quants.length-1]; // invalid
	}

	@:noCompletion private static function set_swagWidth(val:Float){
		halfWidth = val * 0.5;
		return swagWidth = val;
	}

	////	
    /**note generator script (used for shit like pixel notes or skin mods) ((script provided by the HUD skin))*/
    public var genScript:FunkinHScript;
	/**note type script*/
	public var noteScript:FunkinHScript;
	public var extraData:Map<String, Dynamic> = [];
	
	// basic stuff
	public var beat:Float = 0;
	public var strumTime(default, set):Float = 0;

	public var visualTime:Float = 0;
	public var mustPress:Bool = false;
	public var ignoreNote:Bool = false;
	public var prevNote:Note;
	public var nextNote:Note;

	// hold shit
	public var holdType:SustainPart = TAP;
	public var isSustainNote:Bool = false;
	public var isSustainEnd:Bool = false;
	public var isRoll:Bool = false;
	public var isHeld:Bool = false;
	public var parent:Note;
	public var sustainLength:Float = 0;
	public var holdingTime:Float = 0;
	public var tripProgress:Float = 0;
	public var tail:Array<Note> = []; 
	public var unhitTail:Array<Note> = [];

	// quant shit
	public var row:Int = 0;
	public var quant:Int = 4;
	public var isQuant:Bool = false; // mainly for color swapping, so it changes color depending on which set (quants or regular notes)

	// note status
	public var spawned:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var hitByOpponent:Bool = false;
	public var noteWasHit:Bool = false;
	public var causedMiss:Bool = false;
	public var canBeHit(get, never):Bool;

	public var hitResult:HitResult = {judgment: UNJUDGED, hitDiff: 0}
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; //9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	
	// note type/customizable shit
	public var canQuant:Bool = true; // whether a quant texture should be searched for or not
    public var noteMod(default, set):String = null; 
	public var noteType(default, set):String = null;  // the note type
	public var usesDefaultColours:Bool = true; // whether this note uses the default note colours (lets you change colours in options menu)
	// This automatically gets set if a notetype changes the ColorSwap values

	public var texture(default, set):String; // texture for the note
	public var breaksCombo:Bool = false; // hitting this will cause a combo break
	public var blockHit:Bool = false; // whether you can hit this note or not
	public var hitCausesMiss:Bool = false; // hitting this causes a miss
	public var missHealth:Float = 0; // damage when hitCausesMiss = true and you hit this note
	public var noAnimation:Bool = false; // disables the animation for hitting this note
	public var noMissAnimation:Bool = false; // disables the animation for missing this note
	public var hitsoundDisabled:Bool = false; // hitting this does not cause a hitsound when user turns on hitsounds
	public var gfNote:Bool = false; // gf sings this note (pushes gf into characters array when the note is hit)
	public var characters:Array<Character> = []; // which characters sing this note, leave blank for the playfield's characters
	public var fieldIndex:Int = -1; // Used to denote which PlayField to be placed into
	// Leave -1 if it should be automatically determined based on mustPress and placed into either bf or dad's based on that.
	// Note that holds automatically have this set to their parent's fieldIndex
	public var field:PlayField; // same as fieldIndex but lets you set the field directly incase you wanna do that i  guess

	#if PE_MOD_COMPATIBILITY
	public var lowPriority:Bool = false; // Shadowmario's shitty workaround for really bad mine placement, yet still no *real* hitbox customization lol! Only used when PE Mod Compat is enabled in project.xml
	#end

	
	/** If not null, then the characters will play these anims instead of the default ones when hitting this note. **/
	public var characterHitAnimName:Null<String> = null;
	/** If not null, then the characters will play these anims instead of the default ones when missing this note. **/
	public var characterMissAnimName:Null<String> = null;
	// suffix to be added to the base default anim names (for ex. the resulting anim name to be played would be 'singLEFT'+'suffix'+'miss')
	// gets unused if the default anim names are overriden by the vars above
	public var characterHitAnimSuffix:String = "";
	public var characterMissAnimSuffix:String = "";

	/** If you need to tap the note to hit it, or just have the direction be held when it can be judged to hit.
	An example is Stepmania mines **/
	public var requiresTap:Bool = true; 

	/** The maximum amount of time you can release a hold before it counts as a miss**/
	public var maxReleaseTime:Float = 0.25;

	public var noteSplashBehaviour:SplashBehaviour = DEFAULT;
	public var noteSplashDisabled(get, set):Bool; // shortcut, disables the notesplash when you hit this note
	public var noteSplashTexture:String = null; // spritesheet for the notesplash
	public var noteSplashHue:Float = 0; // hueshift for the notesplash, can be changed in note-type but otherwise its whatever the user sets in options
	public var noteSplashSat:Float = 0; // ditto, but for saturation
	public var noteSplashBrt:Float = 0; // ditto, but for brightness

	// event shit (prob can be removed??????)
	public var eventName:String = '';
	public var eventVal1:String = '';
	public var eventVal2:String = '';
	public var eventVal3:String = '';
	public var eventLength:Int = 0;

	// etc
	public var inEditor:Bool = false;
	public var desiredZIndex:Float = 0;

	// mod manager
	public var garbage:Bool = false; // if this is true, the note will be removed in the next update cycle
	public var alphaMod:Float = 1;
	public var alphaMod2:Float = 1; // TODO: unhardcode this shit lmao
	public var typeOffsetX:Float = 0; // used to offset notes, mainly for note types. use in place of offset.x and offset.y when offsetting notetypes
	public var typeOffsetY:Float = 0;
	public var typeOffsetAngle:Float = 0;
	public var multSpeed:Float = 1.0;

	// do not tuch
	public var baseScaleX:Float = 1;
	public var baseScaleY:Float = 1;
	public var zIndex:Float = 0;
	public var z:Float = 0;
	public var realColumn:Int;
	public var vec3Cache:Vector3 = new Vector3(); // for vector3 operations in modchart code

	// unused
	public var mAngle:Float = 0;
	public var bAngle:Float = 0;

	// Determines how the note can be modified by the modchart system
	// Could be moved into NoteObject? idk lol
	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAlpha:Bool = true;
	public var copyVerts:Bool = true;
	#if PE_MOD_COMPATIBILITY
	@:isVar
	public var multAlpha(get, set):Float;
	function get_multAlpha()return alphaMod;
	function set_multAlpha(v:Float)return alphaMod = v;
	
	// Angle is controlled by verts in the modchart system

	@:isVar public var copyAngle(get, set):Bool;
	function get_copyAngle()return copyVerts;
	function set_copyAngle(val:Bool)return copyVerts = val;
	#end

	//// backwards compat
	@:noCompletion public var realNoteData(get, set):Int; 
	@:noCompletion inline function get_realNoteData() return realColumn;
	@:noCompletion inline function set_realNoteData(v:Int) return realColumn = v;
	
	//public var ratingDisabled:Bool = false; // disables judging this note

	@:noCompletion function set_strumTime(val:Float){
        row = Conductor.secsToRow(val);
        return strumTime = val;
    }

	@:noCompletion function get_canBeHit() return UNJUDGED != PlayState.instance.judgeManager.judgeNote(this);

	@:noCompletion inline function get_noteSplashDisabled() return noteSplashBehaviour == DISABLED;
	@:noCompletion inline function set_noteSplashDisabled(val:Bool) {
		noteSplashBehaviour = val ? DISABLED : DEFAULT;
		return val;
	}

	////
	private function set_texture(value:String):String {
        if (tex != value) reloadNote(texPrefix, value, texSuffix);
        return tex;
	}

	public function updateColours(ignore:Bool=false){		
		if (!ignore && !usesDefaultColours) return;
		if (colorSwap==null) return;
		if (column == -1) return; // FUCKING PSYCH EVENT NOTES!!!
		
		var hsb = isQuant ? ClientPrefs.quantHSV[quants.indexOf(quant)] : ClientPrefs.arrowHSV[column % 4];
		if (hsb != null){ // sigh
			colorSwap.hue = hsb[0] / 360;
			colorSwap.saturation = hsb[1] / 100;
			colorSwap.brightness = hsb[2] / 100;
		}else{
			colorSwap.hue = 0.0;
			colorSwap.saturation = 0.0;
			colorSwap.brightness = 0.0;
		}

		if (noteScript != null)
		{
			noteScript.executeFunc("onUpdateColours", [this], this);
		}

		if (genScript != null)
		{
			genScript.executeFunc("onUpdateColours", [this], this);
		}
	}

    private function set_noteMod(value:String):String
    {
        if(value == null)
            value = 'default';

        updateColours();

		colorSwap = new ColorSwap();
		shader = colorSwap.shader;

		// just to make sure they arent 0, 0, 0
		colorSwap.hue += 0.0127;
		colorSwap.saturation += 0.0127;
		colorSwap.brightness += 0.0127;
		var hue = colorSwap.hue;
		var sat = colorSwap.saturation;
		var brt = colorSwap.brightness;

		if (usesDefaultColours)
		{
			if (colorSwap.hue != hue || colorSwap.saturation != sat || colorSwap.brightness != brt)
			{
				usesDefaultColours = false; // just incase
			}
		}

		if (colorSwap.hue == hue)
			colorSwap.hue -= 0.0127;

		if (colorSwap.saturation == sat)
			colorSwap.saturation -= 0.0127;

		if (colorSwap.brightness == brt)
			colorSwap.brightness -= 0.0127;

		if (!inEditor && PlayState.instance != null){
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
					break;
                }
            }
			genScript = script;
        }

		if (genScript == null || !genScript.exists("setupNoteTexture")){
			texture = "";
			if (genScript != null)
			{
				if (genScript.exists("texturePrefix"))
					texPrefix = genScript.get("texturePrefix");

				if (genScript.exists("textureSuffix"))
					texSuffix = genScript.get("textureSuffix");
			}
			
			if (genScript != null && genScript.exists("noteTexture"))
			texture = genScript.get("noteTexture");
        }
        else if(genScript.exists("setupNoteTexture"))
            genScript.executeFunc("setupNoteTexture", [this]);
        

		if (!isSustainNote && column > -1 && column < colArray.length)
		{
			var col:String = colArray[column % colArray.length];
			animation.play(col + 'Scroll');
        }

        return noteMod = value;
    }

	private function set_noteType(value:String):String {
		noteSplashTexture = PlayState.splashSkin;
		if (noteSplashTexture == null || noteSplashTexture.length < 1)
			noteSplashTexture = 'noteSplashes';
		if (value == 'Hurt Note')
			value = 'Mine';

		updateColours();

		// just to make sure they arent 0, 0, 0
		colorSwap.hue += 0.0127;
		colorSwap.saturation += 0.0127;
		colorSwap.brightness += 0.0127;
		var hue = colorSwap.hue;
		var sat = colorSwap.saturation;
		var brt = colorSwap.brightness;

        // TODO: add the ability to override these w/ scripts lol
		if(column > -1 && noteType != value) 
		{
			noteScript = null;

			switch(value) {
				case 'No Animation':
					noAnimation = true;
					noMissAnimation = true;

				case 'GF Sing':
					gfNote = true;

				default:
					
					if (inEditor){
						if (ChartingState.instance != null)
							noteScript = ChartingState.instance.notetypeScripts.get(value);
					}else if (PlayState.instance != null){
						noteScript = PlayState.instance.notetypeScripts.get(value);					
					}

					if (noteScript != null)
						noteScript.executeFunc("setupNote", [this], this, ["this" => this]);

					if (genScript != null)
						genScript.executeFunc("setupNoteType", [this], this, ["this" => this]);
			}

			noteType = value;
		}

		if(usesDefaultColours){
			if(colorSwap.hue != hue || colorSwap.saturation != sat || colorSwap.brightness != brt){
				usesDefaultColours = false;// just incase
			}
		}

		if(colorSwap.hue==hue)
			colorSwap.hue -= 0.0127;

		if(colorSwap.saturation==sat)
			colorSwap.saturation -= 0.0127;

		if(colorSwap.brightness==brt)
			colorSwap.brightness -= 0.0127;

		////

		if (noteScript != null)
			noteScript.executeFunc("postSetupNote", [this], this, ["this" => this]);

		if (genScript != null)
			genScript.executeFunc("postSetupNoteType", [this], this, ["this" => this]);

		////
		if (isQuant && Paths.imageExists('QUANT' + noteSplashTexture))
			noteSplashTexture = 'QUANT' + noteSplashTexture;

		if (!isQuant || (isQuant && noteSplashTexture.startsWith("QUANT"))){
			noteSplashHue = colorSwap.hue;
			noteSplashSat = colorSwap.saturation;
			noteSplashBrt = colorSwap.brightness;
		}
		return value;
	}

	override function toString()
	{
		return '(column: $column | noteType: $noteType | strumTime: $strumTime | visible: $visible)';
	}

	public function new(strumTime:Float, column:Int, ?prevNote:Note, gottaHitNote:Bool = false, susPart:SustainPart = TAP, ?inEditor:Bool = false, ?noteMod:String = 'default')
	{
		super();
		this.objType = NOTE;
		var offset:Float = 0;

		this.strumTime = strumTime;
		this.column = column;
		this.prevNote = (prevNote==null) ? this : prevNote;
		this.mustPress = gottaHitNote;
		this.holdType = susPart;
		this.isSustainNote = susPart != HEAD && susPart != TAP; // susPart > HEAD
		this.isSustainEnd = susPart == END;
		this.inEditor = inEditor;
		this.beat = Conductor.getBeat(strumTime);

		if (canQuant && ClientPrefs.noteSkin == 'Quants'){
			if (isSustainNote && prevNote != null)
				quant = prevNote.quant;
			else
				quant = getQuant(Conductor.getBeatSinceChange(this.strumTime - offset));
		}
		baseAlpha = isSustainNote ? 0.6 : 1;

		if ((FlxG.state is PlayState))
			this.strumTime -= (cast FlxG.state).offset;

		if (!inEditor){ 
			this.strumTime += ClientPrefs.noteOffset;            
            visualTime = PlayState.instance.getNoteInitialTime(this.strumTime);
		}

		if (column >= 0) 
			this.noteMod = noteMod;
		else
			this.colorSwap = new ColorSwap();

		if (prevNote != null){
			prevNote.nextNote = this;

			if (isSustainNote)
			{
				hitsoundDisabled = true;

				if (genScript != null && genScript.exists("setupHoldNoteTexture"))
					genScript.executeFunc("setupHoldNoteTexture", [this]);

				if (isSustainEnd){
					animation.play(colArray[column % 4] + 'holdend');
				}else{
					animation.play(colArray[column % 4] + 'hold');
				}

				scale.y *= Conductor.stepCrochet * 1.5 * PlayState.instance.songSpeed;
				updateHitbox();
			}
		}

		defScale.copyFrom(scale);
	}

	public var texPrefix:String = '';
	public var tex:String;
	public var texSuffix:String = '';
	// should move this to Paths maybe
	public static function getQuantTexture(dir:String, fileName:String, textureKey:String) {
		var quantKey:Null<String>;

		if (quantShitCache.exists(textureKey)) {
			quantKey = quantShitCache.get(textureKey);

		}else {
			quantKey = dir + "QUANT" + fileName;
			if (!Paths.imageExists(quantKey)) quantKey = null;
			quantShitCache.set(textureKey, quantKey);
		}

		return quantKey;
	}
public function reloadNote(?prefix:String, ?texture:String, ?suffix:String, ?folder:String, hInd:Int = 0, vInd:Int = 0) {
		if(prefix == null) prefix = '';
		if(texture == null) texture = '';
		if(suffix == null) suffix = '';
		if(folder == null) folder = '';

		texPrefix = prefix;
		tex = texture;
		texSuffix = suffix;

		if (genScript != null)
			genScript.executeFunc("onReloadNote", [this, prefix, texture, suffix], this);
		
		if (noteScript != null)
			noteScript.executeFunc("onReloadNote", [this, prefix, texture, suffix], this);

		if (genScript != null && genScript.executeFunc("preReloadNote", [this, prefix, texture, suffix], this) == Globals.Function_Stop)
			return;

		////

		/** Should join and check for shit in the following order:
		 * 
		 * folder + "/" + "QUANT" + prefix + name + suffix
		 * folder + "/" + prefix + name + suffix
		 * "QUANT"+ prefix + name + suffix
		 * prefix + name + suffix
		 */
		inline function getTextureKey() { // made it a function just cause i think it's easier to read it like this
			var skin:String = (texture.length>0) ? texture : PlayState.arrowSkin;
			if (skin.length == 0 || skin == '' || skin == null)skin = 'NOTE_assets';
			var split:Array<String> = skin.split('/');
			split[split.length - 1] = prefix + split[split.length-1] + suffix; // add prefix and suffix to the texture file

			var fileName:String = split.pop();
			var folderName:String = folder + split.join('/');
			var foldersToCheck:Array<String> = (folderName == '') ? [''] : ['$folderName/', ''];
			var loadQuants:Bool = canQuant && ClientPrefs.noteSkin=='Quants';

			var key:String = null;
			for (dir in foldersToCheck) {
				key = dir + fileName;
	
				if (loadQuants) {
					var quantKey:Null<String> = getQuantTexture(dir, fileName, key);
					if (quantKey != null) {
						key = quantKey;
						isQuant = true;
						break;
					}
				}
				
				if (Paths.imageExists(key)) {
					isQuant = false;
					break;
				}
			}
			
			return key; 
		}

		////
		var wasQuant:Bool = isQuant;
		var textureKey:String = getTextureKey();
		if (wasQuant != isQuant) updateColours();
 		
		if (vInd > 0 && hInd > 0) {
			var graphic = Paths.image(textureKey);
			setSize(graphic.width / hInd, graphic.height / vInd);
			loadGraphic(graphic, true, Math.floor(width), Math.floor(height));
			loadIndNoteAnims();
		}else {	
			frames = Paths.getSparrowAtlas(textureKey);
			loadNoteAnims();
		} 
	
		if (inEditor)
			setGraphicSize(ChartingState.GRID_SIZE, ChartingState.GRID_SIZE);
		
		defScale.copyFrom(scale);
		updateHitbox();
		
		////	
		if (genScript != null)
			genScript.executeFunc("postReloadNote", [this, prefix, texture, suffix], this);

		if (noteScript != null)
			noteScript.executeFunc("postReloadNote", [this, prefix, texture, suffix], this);
	}


	public function loadIndNoteAnims()
	{
		var con = true;
		if (noteScript != null)
		{
			if (noteScript.exists("loadIndNoteAnims") && Reflect.isFunction(noteScript.get("loadIndNoteAnims")))
			{
				noteScript.executeFunc("loadIndNoteAnims", [this], this, ["super" => _loadIndNoteAnims]);
				con = false;
			}
		}

		if (genScript != null)
		{
			if (genScript.exists("loadIndNoteAnims") && Reflect.isFunction(genScript.get("loadIndNoteAnims")))
			{
				genScript.executeFunc("loadIndNoteAnims", [this], this, ["super" => _loadIndNoteAnims, "noteTypeLoaded" => con]);
				con = false;
			}
		}
		if (!con)
			return;
		_loadIndNoteAnims();
	}

	function _loadIndNoteAnims()
	{
		var data = DATA_AMOUNT;
		if (DATA_AMOUNT > colArray.length)
			data = colArray.length;
		var colorName:String = colArray[column % data];		
		var animName:String;
		var animFrames:Array<Int>;
		var targetPixel:Null<Int> = pixelTarget[column % data];
		if (targetPixel == null)
			targetPixel = column;
		switch (holdType) {
			default:	
				animName = colorName+'Scroll';
				animFrames = [targetPixel + data];

			case PART:
				animName = colorName+'hold';
				animFrames = [targetPixel];
 
			case END:
				animName = colorName+'holdend';
				animFrames = [targetPixel + data];
		} 
 
		animation.add(animName, animFrames);
		animation.play(animName, true);

	}


	public function loadNoteAnims() {
        var con = true;
		if (noteScript != null){
			if (noteScript.exists("loadNoteAnims") && Reflect.isFunction(noteScript.get("loadNoteAnims"))){
				noteScript.executeFunc("loadNoteAnims", [this], this, ["super" => _loadNoteAnims]);
				con = false;
			}
		}

		if (genScript != null)
		{
			if (genScript.exists("loadNoteAnims") && Reflect.isFunction(genScript.get("loadNoteAnims")))
			{
				genScript.executeFunc("loadNoteAnims", [this], this, ["super" => _loadNoteAnims, "noteTypeLoaded" => con]);
				con = false;
			}
		}
		if (!con)return;

		_loadNoteAnims();
	}

	function _loadNoteAnims() {
		var data = DATA_AMOUNT;
		if (DATA_AMOUNT > colArray.length)
			data = colArray.length;
		var colorName:String = colArray[column % data];		
		var animName:String;
		var animPrefix:String;

		switch (holdType) {
			default:	
				animName = colorName+'Scroll';
				animPrefix = colorName+'0';
 
			case PART:
				animName = colorName+'hold';
				animPrefix = '$colorName hold piece';
				
 
			case END:
				animName = colorName+'holdend';
				animPrefix = '$colorName hold end';
				if (colorName == "purple")
					animPrefix ='pruple end hold'; // ?????
				// this is autistic wtf
				
		} 
 
		animation.addByPrefix(animName, animPrefix);
		animation.play(animName, true);
 
		scale.set(spriteScale, spriteScale); 
	}

	override function draw()
	{
		var holdMult:Float = baseAlpha;

		if (isSustainNote && parent.wasGoodHit && holdGlow)
			holdMult = FlxMath.lerp(0.3, 1, parent.tripProgress);
        
		colorSwap.daAlpha = alphaMod * alphaMod2 * holdMult;

		if (tooLate && !inEditor)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}

		super.draw();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(!inEditor){
			if (noteScript != null){
				noteScript.executeFunc("noteUpdate", [elapsed], this);
			}

			if (genScript != null){
				genScript.executeFunc("noteUpdate", [elapsed], this);
            }
		}

		if (hitByOpponent)
			wasGoodHit = true;

		var diff = (strumTime - Conductor.songPosition);
		if (diff < -Conductor.safeZoneOffset && !wasGoodHit)
			tooLate = true;
	}
}
