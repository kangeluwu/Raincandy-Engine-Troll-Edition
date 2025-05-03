package funkin.states;

import funkin.data.CharacterData;
import funkin.data.Cache;
import funkin.data.Song;
import funkin.data.Section;
import funkin.objects.Note;
import funkin.objects.NoteObject;
import funkin.objects.NoteObject.ObjectType;
import funkin.objects.NoteSplash;
import funkin.objects.StrumNote;
import funkin.objects.Stage;
import funkin.objects.Character;
import funkin.objects.RatingGroup;
import funkin.objects.hud.*;
import funkin.objects.playfields.*;
import funkin.data.Stats;
import funkin.data.JudgmentManager;
import funkin.data.Highscore;
import funkin.data.WeekData;
import funkin.states.GameOverSubstate;
import funkin.states.GameOverSubstateAlt;
import funkin.states.PauseSubState;
import funkin.modchart.Modifier;
import funkin.modchart.ModManager;
import funkin.states.editors.*;
import funkin.states.options.*;
import funkin.scripts.*;
import funkin.scripts.Util;
import funkin.scripts.Util as ScriptingUtil;
import funkin.objects.FunkinCamera as FlxCamera;
import flixel.*;
import flixel.util.*;
import flixel.math.*;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import funkin.objects.IndependentVideoSprite as FlxVideoSprite;
import haxe.Json;
import openfl.filters.BlurFilter;
import flixel.graphics.frames.FlxFilterFrames;
import lime.media.openal.AL;
import lime.media.openal.ALFilter;
import lime.media.openal.ALEffect;

import openfl.events.KeyboardEvent;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;

using StringTools;

#if DISCORD_ALLOWED
import funkin.api.Discord.DiscordClient;
#end

#if (!VIDEOS_ALLOWED) typedef VideoHandler = Dynamic;
#elseif (hxCodec >= "3.0.0") import hxcodec.flixel.FlxVideo as VideoHandler;
#elseif (hxCodec >= "2.6.1") import hxcodec.VideoHandler as VideoHandler;
#elseif (hxCodec == "2.6.0") import VideoHandler;
#elseif (hxCodec) import vlc.MP4Handler as VideoHandler; 
#elseif (hxvlc) import hxvlc.flixel.FlxVideo as VideoHandler;
#end

/*
okay SO im gonna explain how these work

All speed changes are stored in an array, .sort()'d by the time
if changes[0].songTime is above conductor.songposition then 
	- it'll remove the first element of changes
	- it'll store the position, songTime and speed of the change somewhere
	- and then it'll songVisualPos = event.position + getVisPos(conductor.songPosition - event.songTime, songSpeed * event.speed)

all notes will also store their visualPos in a variable when creation and then when moving notes it's just
	note.y = note.visualPos - event.position
:3

EDIT: not EXACTLY how it works but its a good enough summary
*/
typedef SpeedEvent =
{
	position:Float, // the y position where the change happens (modManager.getVisPos(songTime))
	startTime:Float, // the song position (conductor.songTime) where the change starts
	songTime:Float, // the song position (conductor.songTime) when the change ends
	?startSpeed:Float, // the starting speed
	speed:Float // speed mult after the change
}

@:noScripting
class PlayState extends MusicBeatState
{    
	public static var instance:PlayState;
	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var songPlaylist:Array<SongMetadata> = [];
	public static var songPlaylistIdx = 0;
	public static var storyWeek:Int = 0;
	@:isVar public static var storyPlaylist(get, null):Array<String> = [];// for psych mod shit
	@:noCompletion static function get_storyPlaylist()
		{
			var data = [];
			for (song in songPlaylist){
				data.push(song.songName);
			}
			return data;
		}


	public static var difficulty:Int = 1; // for psych mod shit
	public static var difficultyName:String = 'normal'; // should NOT be set to "" when playing normal diff!!!!!
	public static var curStage:String = 'stage';
	public static var arrowSkin:String = 'NOTE_assets'; 
	public static var holdSkin:String = 'holdCover'; 
	public static var keyCount:Int = 4;
	public static var splashSkin:String = NoteSplash.defaultNoteSplash; 
	public static var chartingMode:Bool = false;
	public static var startOnTime:Float = 0;
	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;
	public var curStrum:Int = 2;
	
	////
	public var showDebugTraces:Bool = #if debug true #else Main.showDebugTraces #end;

	//// Gameplay settings
	public var healthGain:Float = 1.0;
	public var healthLoss:Float = 1.0;
	public var healthDrain:Float = 0.0;
	public var opponentHPDrain:Float = 0.0;

	public var songSpeed(default, set):Float = 1.0;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;
	public var playbackRate:Float = 1.0;
	public var currentPlayerStrum:Int = 0;
	public var currentOpponentStrum:Int = 1;
	public var disableModcharts:Bool = false;
	public var practiceMode:Bool = false;
	public var perfectMode:Bool = false;
	public var instaRespawn:Bool = false;
	public var cpuControlled(default, set):Bool = false;
	public static var rhythmMode:Bool = false;
	public var backGroundSprite:FlxSprite = new FlxSprite();
	public var backGroundVideo:FlxVideoSprite = null;
	public var backGroundAssets:String = 'menuDesat';
	public var playOpponent:Bool = false;
	public var instakillOnMiss:Bool = false;

	public var midScroll:Bool = false; // whether midscroll is active, songs can force this off prior to countdown start and modchart generation
	public var saveScore:Bool = true; // whether to save the score. modcharted songs should set this to false if disableModcharts is true

	////
	public var worldCombos:Bool = false;
	public var showRating:Bool = true;
	public var showCombo:Bool = false;
	public var showComboNum:Bool = true;

	public var skipCountdown:Bool = false;

	////
	public var displayedSong:String = null;
	public var displayedDifficulty:String;
	public var metadata:SongCreditdata; // metadata for the songs (artist, etc)

	public var stats:Stats = new Stats();
	public var ratingStuff:Array<Array<Dynamic>> = Highscore.grades.get(ClientPrefs.gradeSet);
	public var noteHits:Array<Float> = [];
	public var nps:Int = 0;
	
	public var trackMap = new Map<String, FlxSound>();
	public var tracks:Array<FlxSound> = [];

	public var instTracks:Array<FlxSound>;
	public var playerTracks:Array<FlxSound>;
	public var opponentTracks:Array<FlxSound>;

	public var inst:FlxSound;
	public var vocals:FlxSound = null;
	
	var sndFilter:ALFilter = AL.createFilter();
	var sndEffect:ALEffect = AL.createEffect();

	////
	public var camGame:FlxCamera;
	public var camStageUnderlay:FlxCamera; // retarded
	public var camHUD:FlxCamera;
	public var camOverlay:FlxCamera; // shit that should go above all else and not get affected by camHUD changes, but still below camOther (pause menu, etc)
	public var camOther:FlxCamera;
	public var camRhythm:FlxCamera;
	public var camRhythmHUD:FlxCamera;
	public var subStateCam:FlxCamera;
	public var camFollow:FlxPoint;
	public var camFollowPos:FlxObject;
	private static var prevCamFollow:Null<FlxPoint> = null;
	private static var prevCamFollowPos:Null<FlxObject> = null;

	public var camZooming(default, set):Bool = false;
	public var camZoomingMult:Float = 1.0;
	public var camZoomingDecay:Float = 1.0;
	@:noCompletion function set_camZooming(value:Bool){
		camGame.useLerp = value;
		camHUD.useLerp = value;
		camZooming  = value;
		return value;
	}
	public var cameraSpeed(default, set):Float = 1.0;
	@:noCompletion function set_cameraSpeed(value:Float){
		camGame.cameraSpeed = value;
		camHUD.cameraSpeed = value;
		cameraSpeed  = value;
		return value;
	}
	public var defaultCamZoom(default, set):Float = 1.0;
	public var defaultCamZoomAdd(default, set):Float = 0;
	@:noCompletion function set_defaultCamZoom(value:Float){
		camGame.defaultCamZoom = value + defaultCamZoomAdd;
		defaultCamZoom  = value;
		return value;
	}
	@:noCompletion function set_defaultCamZoomAdd(value:Float){
		camGame.defaultCamZoom = defaultCamZoom + value;
		defaultCamZoomAdd  = value;
		return value;
	}
	public var defaultHudZoom(default, set):Float = 1.0;
	@:noCompletion function set_defaultHudZoom(value:Float){
		camHUD.defaultCamZoom = value;
		defaultHudZoom  = value;
		return value;
	}
	public var sectionCamera = new FlxPoint(); // Default camera focus point
	public var customCamera = new FlxPoint(); // Used for the 'Camera Follow Pos' event
	public var cameraPoints:Array<FlxPoint>;
	public var cameraAdded:Bool = false;
	public function addCameraPoint(point:FlxPoint){
		cameraPoints.remove(point);
		cameraPoints.push(point);
	}

	////
	public var stage:Stage;
	private var stageData:StageFile;

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public static var isPixelStage:Bool = false;
	//// Used for character change events	
	public var boyfriendMap:Map<String, Character> = new Map();
	public var dadMap:Map<String, Character> = new Map();
	public var gfMap:Map<String, Character> = new Map();
	public var extraMap:Map<String, Character> = new Map();

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	private var singAnimations:Array<String> = ["singLEFT", "singDOWN", "singUP", "singRIGHT"];

	public var focusedChar:Character;
	public var gfSpeed:Int = 1;

	public var notes = new FlxTypedGroup<Note>();
	public var unspawnNotes:Array<Note> = [];
	public var allNotes:Array<Note> = []; // all notes
	public var eventNotes:Array<EventNote> = [];

	var speedChanges:Array<SpeedEvent> = [];
	public var currentSV:SpeedEvent = {position: 0, startTime: 0, songTime:0, speed: 1, startSpeed: 1};
	public var judgeManager:JudgmentManager;

	public var modManager:ModManager;
	public var notefields = new NotefieldManager();
	public var playfields = new FlxTypedGroup<PlayField>();
	public var grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
	public var fields:Array<PlayField> =  [];
	public var playerField:PlayField;
	public var dadField:PlayField;

	/** Group instance containing HUD objects **/
	public var hud:BaseHUD; // perhaps this and 'hudSkins' could and/or should be fused together
	
	public var ratingGroup:RatingGroup;
	public var timingTxt:FlxText;

	/** debugPrint text container **/
    #if(LUA_ALLOWED || HSCRIPT_ALLOWED)
    private var luaDebugGroup:FlxTypedGroup<DebugText> = new FlxTypedGroup<DebugText>();
    #end

	////	

	/** Formatted song name **/
	public var songName:String = "";
	public var songLength:Float = 0;
	public var songHighscore:Int = 0;
	public var songTrackNames:Array<String> = [];

	////
	private var generatedMusic:Bool = false;
	public var startingSong:Bool = false;
	public var inCutscene:Bool = false;
	public var endingSong:Bool = false;

	public var songHits:Int = 0;
	public var songMisses:Int = 0;

	public var health(default, set):Float = 1.0;
	public var maxHealth:Float = 2.0;
	public var missSuffix:String = '';
	/** Health value to be displayed on the HUD **/
	public var displayedHealth(default, set):Float = 1.0;

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;
	public var curCountdown:Countdown;
	public var songSpeedTween:FlxTween;
	
	public var introAlts:Array<Null<String>> = ["onyourmarks", 'ready', 'set', 'go'];
	public var introSnds:Array<Null<String>> = ["intro3", 'intro2', 'intro1', 'introGo'];
	public var introSoundsSuffix:String = '';
	
	public var countdownSpr:Null<FlxSprite>;
	public var countdownSnd:Null<FlxSound>;
	public var countdownTwn:FlxTween;
	
    public var startedOnTime:Float = 0;

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysBotplay:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Less laggy controls
	private var keysArray:Array<Dynamic>;
	private var controlArray:Array<String>;

	//// for backwards compat reasons. these aren't ACTUALLY used
	#if PE_MOD_COMPATIBILITY
	@:noCompletion public var healthBar:FNFHealthBar; 
	@:noCompletion public var iconP1:HealthIcon;
	@:noCompletion public var iconP2:HealthIcon;

	@:noCompletion public var scoreTxt:FlxText;
	@:noCompletion public var botplayTxt:FlxText;

	@:noCompletion var songPercent:Float = 0;
	
	@:noCompletion public var spawnTime:Float = 1500;

	@:noCompletion public static var STRUM_X = 42;
	@:noCompletion public static var STRUM_X_MIDDLESCROLL = -278;

	@:noCompletion public var strumLineNotes:FlxTypedGroup<StrumNote>;
	@:noCompletion public var opponentStrums:FlxTypedGroup<StrumNote>;
	@:noCompletion public var playerStrums:FlxTypedGroup<StrumNote>;
	#end

	// nightmarevision compatibility shit !
	public var whosTurn:String = 'dad';

	@:isVar public var beatsPerZoom(get, set):Int = 4;
	@:noCompletion function get_beatsPerZoom()return zoomEveryBeat;
	@:noCompletion function set_beatsPerZoom(val:Int)return zoomEveryBeat = val;

	////
	@:isVar public var botplay(get, set):Bool = false;
	@:isVar public var opponentPlayer(get, set):Bool = false;
	@:isVar public var songScore(get, set):Int = 0;
	@:isVar public var totalPlayed(get, set):Float = 0;
	@:isVar public var totalNotesHit(get, set):Float = 0.0;
	@:isVar public var combo(get, set):Int = 0;
	@:isVar public var cbCombo(get, set):Int = 0;
	@:isVar public var ratingName(get, set):String = '?';
	@:isVar public var ratingPercent(get, set):Float;
	@:isVar public var ratingFC(get, set):String;

	@:isVar public var sicks(get, set):Int = 0;
	@:isVar public var goods(get, set):Int = 0;
	@:isVar public var bads(get, set):Int = 0;
	@:isVar public var shits(get, set):Int = 0;

	@:noCompletion public inline function get_opponentPlayer()return playOpponent;
	@:noCompletion public inline function get_botplay()return cpuControlled;
	@:noCompletion public inline function get_songScore()return stats.score;
	@:noCompletion public inline function get_totalPlayed()return stats.totalPlayed;
	@:noCompletion public inline function get_totalNotesHit()return stats.totalNotesHit;
	@:noCompletion public inline function get_combo()return stats.combo;
	@:noCompletion public inline function get_cbCombo()return stats.cbCombo;
	@:noCompletion public inline function get_ratingName()return stats.grade;
	@:noCompletion public inline function get_ratingPercent()return stats.ratingPercent;
	@:noCompletion public inline function get_ratingFC()return stats.clearType;

	@:noCompletion public inline function set_opponentPlayer(val:Bool)return playOpponent = val;
	@:noCompletion public inline function set_botplay(val:Bool)return cpuControlled = val;
	@:noCompletion public inline function set_songScore(val:Int)return stats.score = val;
	@:noCompletion public inline function set_totalPlayed(val:Float)return stats.totalPlayed = val;
	@:noCompletion public inline function set_totalNotesHit(val:Float)return stats.totalNotesHit = val;
	@:noCompletion public inline function set_combo(val:Int)return stats.combo = val;
	@:noCompletion public inline function set_cbCombo(val:Int)return stats.cbCombo = val;
	@:noCompletion public inline function set_ratingName(val:String)return stats.grade = val;
	@:noCompletion public inline function set_ratingPercent(val:Float)return stats.ratingPercent = val;
	@:noCompletion public inline function set_ratingFC(val:String)return stats.clearType = val;

	@:noCompletion public inline function set_goods(val:Int){
		stats.judgements.set('good',val);
		return val;
	}
	@:noCompletion public inline function get_goods(){
		return stats.judgements.get('good');
	}

	@:noCompletion public inline function set_sicks(val:Int){
		stats.judgements.set('sick',val);
		return val;
	}
	@:noCompletion public inline function get_sicks(){
		return stats.judgements.get('sick');
	}

	@:noCompletion public inline function set_bads(val:Int){
		stats.judgements.set('bad',val);
		return val;
	}
	@:noCompletion public inline function get_bads(){
		return stats.judgements.get('bad');
	}

	@:noCompletion public inline function set_shits(val:Int){
		stats.judgements.set('shit',val);
		return val;
	}
	@:noCompletion public inline function get_shits(){
		return stats.judgements.get('shit');
	}
	#if DISCORD_ALLOWED
	// Discord RPC variables
	var detailsText:String = "";
	var detailsPausedText:String = "";
	var stateText:String = "";
	#end

	//// Psych achievement shit
	var keysPressed:Array<Bool> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	//// Script shit
	public var funkyScripts:Array<FunkinScript> = [];
	public var hscriptArray:Array<FunkinHScript> = [];
	public var luaArray:Array<FunkinLua> = [];

	public var scriptsToClose:Array<FunkinScript> = [];
	
	// used by lua scripts
	public var modchartTweens:Map<String, FlxTween> = new Map();
	public var modchartSprites:Map<String, ModchartSprite> = new Map();
	public var modchartTimers:Map<String, FlxTimer> = new Map();
	public var modchartSounds:Map<String, FlxSound> = new Map();
	public var modchartTexts:Map<String, ModchartText> = new Map();
	public var modchartSaves:Map<String, FlxSave> = new Map();
	public var modchartObjects:Map<String, FlxSprite> = new Map();

	public var notetypeScripts:Map<String, FunkinHScript> = []; // custom notetypes for scriptVer '1'
	public var eventScripts:Map<String, FunkinHScript> = []; // custom events for scriptVer '1'
	public var hudSkinScripts:Map<String, FunkinHScript> = []; // Doing this so you can do shit like i.e having it swap between pixel and normal HUD
	
    public var hudSkin(default, set):String;
    public var hudSkinScript:FunkinHScript; // this is the HUD skin used for countdown, judgements, etc

	////
    @:noCompletion function set_hudSkin(value:String){
		var script = hudSkinScripts.get(value);
		if (script == null)
		{
			var baseFile = 'hudskins/$value.hscript';
			var files = [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)];
			for (file in files)
			{
				if (!Paths.exists(file))
					continue;

				
				script = createHScript(file, value);
				hudSkinScripts.set(value, script);
			}
		}
        if (hudSkinScript != null)
            hudSkinScript.call("onSkinUnload");
        
		hudSkinScript = script;

        if(script != null)script.call("onSkinLoad");
        return hudSkin = value;
    }

	@:noCompletion function set_health(value:Float){
		health = FlxMath.bound(value, 0, maxHealth);
		displayedHealth = health;

		return health;
	}

	@:noCompletion function set_displayedHealth(value:Float){
		hud.displayedHealth = value;
		displayedHealth = value;

		return value;
	}

	@:noCompletion function set_cpuControlled(value:Bool):Bool {
		cpuControlled = value;

		setOnScripts('botPlay', value);

		/// oughhh
		for (playfield in playfields.members){
			if (playfield.isPlayer)
				playfield.autoPlayed = cpuControlled; 
		}

		return value;
	}

	function set_songSpeed(value:Float):Float
	{
		songSpeed = value;
		noteKillOffset = 350 / songSpeed;
		return value;
	}

	// Loading
	public var shitToLoad:Array<AssetPreload> = [];
	var finishedCreating = false;
	
    public var offset:Float = 0;

	override public function create()
	{
		Highscore.loadData();

        Paths.preLoadContent = [];
		Paths.postLoadContent = [];
		
		Conductor.safeZoneOffset = ClientPrefs.hitWindow;
		Wife3.timeScale = Conductor.judgeScales.get(ClientPrefs.judgeDiff);

		judgeManager = new JudgmentManager();
		judgeManager.judgeTimescale = Wife3.timeScale;

		modManager = new ModManager(this);

		OptionsSubstate.resetRestartRecomendations();
		Paths.clearStoredMemory();
		#if MODS_ALLOWED
		Paths.pushGlobalContent();
		#end

		//// Reset to default
		PauseSubState.songName = null;
		GameOverSubstate.resetVariables();

		////
		FlxG.fixedTimestep = false;
		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		persistentUpdate = true;
		persistentDraw = true;

		MusicBeatState.stopMenuMusic();

		debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));
		debugKeysBotplay = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('botplay'));

		keysArray = [
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_left')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_down')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_up')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_right'))
		];

		controlArray = [
			'NOTE_LEFT',
			'NOTE_DOWN',
			'NOTE_UP',
			'NOTE_RIGHT'
		];

		speedChanges.push({
			position: 0,
			songTime: 0,
			startTime: 0,
			startSpeed: 1,
			speed: 1,
		});

		#if PE_MOD_COMPATIBILITY
		strumLineNotes = opponentStrums = playerStrums = new FlxTypedGroup<StrumNote>();
		scoreTxt = botplayTxt = new FlxText();

		strumLineNotes.exists = false;
		scoreTxt.exists = false;

		add(strumLineNotes);
		add(scoreTxt);
		#end

		//// For the "Just the Two of Us" achievement
		for (i in 0...keysArray.length)
			keysPressed.push(false);
		
		//// Gameplay settings
		//if (!isStoryMode){
			playbackRate = ClientPrefs.getGameplaySetting('songspeed', playbackRate);
			healthGain = ClientPrefs.getGameplaySetting('healthgain', healthGain);
			healthLoss = ClientPrefs.getGameplaySetting('healthloss', healthLoss);
			playOpponent = ClientPrefs.getGameplaySetting('opponentPlay', playOpponent);
			instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', instakillOnMiss);
			practiceMode = ClientPrefs.getGameplaySetting('practice', practiceMode);
			perfectMode = ClientPrefs.getGameplaySetting('perfect', perfectMode);
			instaRespawn = ClientPrefs.getGameplaySetting('instaRespawn', instaRespawn);
			cpuControlled = ClientPrefs.getGameplaySetting('botplay', cpuControlled);
			disableModcharts = ClientPrefs.getGameplaySetting('disableModcharts', false);
			midScroll = ClientPrefs.midScroll;
			rhythmMode = ClientPrefs.rhythmMode;
			#if tgt
			playbackRate *= (ClientPrefs.ruin ? 0.8 : 1);
			#end

			healthDrain = switch(ClientPrefs.getGameplaySetting('healthDrain', "Disabled")){
				default: 0;
				case "Basic": 0.00055;
				case "Average": 0.0007;
				case "Heavy": 0.00085;
			};
			opponentHPDrain = ClientPrefs.getGameplaySetting('opponentFightsBack', false) ? 0.0182 : 0;
			if (playOpponent){
				currentPlayerStrum = 1;
				currentOpponentStrum = 0;
			}
		//}

		FlxG.timeScale = playbackRate;
		
		if (perfectMode){
			practiceMode = false;
			instakillOnMiss = true;
		}
		saveScore = true; //!cpuControlled;

		//// Camera shit
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camOverlay = new FlxCamera();
		camOther = new FlxCamera();
		camStageUnderlay = new FlxCamera();
		camRhythm = new FlxCamera();
		camRhythmHUD = new FlxCamera();
		subStateCam = new FlxCamera();

		camHUD.bgColor = 0; 
		camOverlay.bgColor = 0;
		camOther.bgColor = 0;
		camStageUnderlay.bgColor = 0;
		camRhythm.bgColor = 0;
		camRhythmHUD.bgColor = 0;
		subStateCam.bgColor = 0;

		camGame.useLerp = true;
		camHUD.useLerp = true;
		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camStageUnderlay, false);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOverlay, false);
		FlxG.cameras.add(camOther, false);
		if (rhythmMode){
		FlxG.cameras.add(camRhythm, false);
		FlxG.cameras.add(camRhythmHUD, false);
		}
		FlxG.cameras.add(subStateCam, false);
		camZooming = false;
		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		cameraAdded = true;
		camFollow = prevCamFollow != null ? prevCamFollow : new FlxPoint();
		camFollowPos = prevCamFollowPos != null ? prevCamFollowPos : new FlxObject();

		FlxG.camera.follow(camFollowPos, LOCKON, 1);
		FlxG.camera.focusOn(camFollow);
		camGame.defaultCamZoom = defaultCamZoom + defaultCamZoomAdd;
		camHUD.defaultCamZoom = defaultHudZoom;
		////
		if (SONG == null){
			trace("WARNING: null SONG");
			SONG = Song.loadFromJson('tutorial', difficultyName, 'tutorial');
		}

		offset = SONG.offset != null ? SONG.offset : 0;
		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);
		
		lastBeatHit = -5;
		Conductor.songPosition = Conductor.crochet * lastBeatHit;

		songName = Paths.formatToSongPath(SONG.song);
		songHighscore = Highscore.getScore(SONG.song, difficultyName);
		modManager.playerAmount = curStrum = SONG.strums;
		modManager.setActive(modManager.playerAmount);
		if (SONG.metadata != null){
			metadata = SONG.metadata;
		}else{
			var jsonPath = Paths.getPath('songs/$songName/metadata'+difficultyName+'.json');
			if (!Paths.exists(jsonPath))jsonPath = Paths.getPath('songs/$songName/metadata.json');
			if (Paths.exists(jsonPath))
				metadata = cast Json.parse(Paths.getContent(jsonPath));
			else{
				if(showDebugTraces)
					trace('No metadata for $songName. Maybe add some?');
			}
		}

		for (groupName in Reflect.fields(SONG.tracks)) {
			var trackGroup:Array<String> = Reflect.field(SONG.tracks, groupName);
			for (trackName in trackGroup) {
				if (trackMap.exists(trackName))
					continue;

				trackMap.set(trackName, null);
				songTrackNames.push(trackName);
			}
		}
		Note.NOTE_AMOUNT = PlayState.keyCount = SONG.keyCount;
		Note.spriteScale = (4 / keyCount) * 0.7 * (2 / curStrum);//SUP
		Note.swagWidth = Note.spriteScale * 160;
		/**
		 * Note texture asset names
		 * The quant prefix gets handled by the Note class
		 */
		arrowSkin = SONG.arrowSkin;
		splashSkin = SONG.splashSkin;

		hudSkin = SONG.hudSkin;

		//// STAGE SHIT
		if (SONG.stage == null || SONG.stage.length < 1)
			curStage = 'stage';
		else
			curStage = SONG.stage;

		////
		instance = this;
		if (Paths.exists(Paths.getPath('songs/'+songName+'/backGroundAssets.txt'))){
			backGroundAssets = Paths.getContent(Paths.getPath('songs/'+songName+'/backGroundAssets.txt'));
		}else if (Paths.exists(Paths.getPath('data/'+songName+'/backGroundAssets.txt'))){
			backGroundAssets = Paths.getContent(Paths.getPath('data/'+songName+'/backGroundAssets.txt'));
		}
		setDefaultHScripts("modManager", modManager);
		setDefaultHScripts("judgeManager", judgeManager);
		setDefaultHScripts("newPlayField", newPlayfield);
		setDefaultHScripts("initPlayfield", initPlayfield);
		if (rhythmMode){
			var blurFilter:BlurFilter = new BlurFilter(6, 6, 2);         
			var blackScreen = CoolUtil.blankSprite(FlxG.width,FlxG.height,FlxColor.BLACK);
			blackScreen.cameras = [camRhythm];
			add(blackScreen);
		if (Paths.imageExists(backGroundAssets)){
			if (Paths.exists(Paths.getPath('images/'+backGroundAssets+'.xml'))){
			backGroundSprite.frames = Paths.getSparrowAtlas(backGroundAssets);
			backGroundSprite.animation.addByPrefix('bg','bg',24,true);
			backGroundSprite.animation.play('bg', true);
			}else{
				backGroundSprite.loadGraphic(Paths.image(backGroundAssets));
			}
		}else{
			backGroundSprite = CoolUtil.blankSprite(FlxG.width,FlxG.height,FlxColor.GRAY);
		}  
		if (Paths.exists(Paths.getPath('videos/'+backGroundAssets+'.mp4'))){
			var precache = new FlxVideoSprite(0,0,false,false); 
			precache.load(backGroundAssets+'.mp4');
			precache.autoVolumeHandle = false;
			precache.bitmap.mute = true;
			if (precache != null)
				precache.play();
			precache.destroy();

			backGroundVideo = new FlxVideoSprite(0,0,false,false);
			backGroundVideo.load(backGroundAssets+'.mp4');
			backGroundVideo.autoVolumeHandle = false;
			backGroundVideo.bitmap.mute = true;
			backGroundVideo.cameras = [camRhythm];

			backGroundVideo.bitmap.onOpening.add(function():Void
				{
					if (backGroundVideo.bitmap != null && backGroundVideo.bitmap.bitmapData != null)
					backGroundVideo.bitmap.time = Std.int(startOnTime);
				});
			
			backGroundVideo.bitmap.onPlaying.add(function():Void
				{
					if (backGroundVideo.bitmap != null && backGroundVideo.bitmap.bitmapData != null){
					
					
			var w = FlxG.width / backGroundVideo.width;
			var h = FlxG.height / backGroundVideo.height;
		
				if (w > h)
					backGroundVideo.scale.set(w,w);
				else 
					backGroundVideo.scale.set(h,h);
			
			
			backGroundVideo.updateHitbox();
			backGroundVideo.screenCenter();
			var filterFrames = FlxFilterFrames.fromFrames(backGroundVideo.frames, Std.int(backGroundVideo.width), Std.int(backGroundVideo.height), [blurFilter]);
			filterFrames.applyToSprite(backGroundVideo, false, true);

					}
				},true);
			
		}
		var filterFrames = FlxFilterFrames.fromFrames(backGroundSprite.frames, Std.int(backGroundSprite.width), Std.int(backGroundSprite.height), [blurFilter]);
		filterFrames.applyToSprite(backGroundSprite, false, true);
		var w = FlxG.width / backGroundSprite.width;
		var h = FlxG.height / backGroundSprite.height;
	
			if (w > h)
				backGroundSprite.scale.set(w,w);
			else 
				backGroundSprite.scale.set(h,h);
			backGroundSprite.updateHitbox();
		backGroundSprite.cameras = [camRhythm];
		backGroundSprite.screenCenter();
		backGroundSprite.alpha = 0.8;
		add(backGroundSprite);
		if (backGroundVideo != null){
			backGroundSprite.alpha = 0;
			backGroundVideo.alpha = 0.00001;
			add(backGroundVideo);
		}
		
	}
		#if LUA_ALLOWED
		FunkinLua.haxeScript = FunkinHScript.blankScript('runHaxeCode');
		#end

		//// GLOBAL SCRIPTS
		var filesPushed:Array<String> = [];
		for (folder in Paths.getFolders('scripts'))
		{
			////
			var orderListRaw = Paths.getContent(folder + 'orderList.txt');

			if (orderListRaw != null){
				//trace('$orderListPath exists');

				for (name in orderListRaw.split('\n'))
				{
					var file = '$name.hscript';
					var filePath = folder + file;

					if (!Paths.exists(filePath) || filesPushed.contains(file)){
						//trace('skipped: $file');
						continue;
					}

					createHScript(filePath);
					filesPushed.push(file);
				}
			}

			////
			Paths.iterateDirectory(folder, function(file:String)
			{
				if(filesPushed.contains(file) || !file.endsWith('.hscript'))
					return;

				createHScript(folder + file);
				filesPushed.push(file);
			});
		}
		//trace("Loaded global scripts in order:" + filesPushed);

		//// STAGE SCRIPTS
		stage = new Stage(curStage, false);
		var vars = new Map<String, Any>();
		initPlayStateVars(vars,true);
		stage.startScript(false,vars);
		stageData = stage.stageData;

		if (stage.stageScript != null){
			hscriptArray.push(stage.stageScript);
			funkyScripts.push(stage.stageScript);
		}

		setStageData(stageData);

		// SONG SPECIFIC SCRIPTS
		var foldersToCheck:Array<String> = Paths.getFolders('songs/$songName');
		#if PE_MOD_COMPATIBILITY
		for (dir in Paths.getFolders('data/$songName'))
			foldersToCheck.push(dir);
		#end

		var filesPushed:Array<String> = [];
		for (folder in foldersToCheck)
		{
			Paths.iterateDirectory(folder, function(file:String)
			{
				if(filesPushed.contains(file) || !file.endsWith('.hscript'))
					return;

				createHScript(folder + file);
				filesPushed.push(file);
			});
		}

		//// Asset precaching start		
		for (judgeData in judgeManager.judgmentData)
			shitToLoad.push({path: judgeData.internalName});

		for (i in 0...10)
			shitToLoad.push({path: 'num$i'});

		for (i in 1...3) // TODO: Be able to add more than 3 miss sounds
			shitToLoad.push({path: 'missnote'+missSuffix+'$i', type: 'SOUND'});

		shitToLoad.push({path: 'hitsound', type: 'SOUND'});
		shitToLoad.push({path: "healthBar"});
		shitToLoad.push({path: "timeBar"});
		shitToLoad.push({path: backGroundAssets});
		/* 
		if (PauseSubState.songName != null)
			shitToLoad.push({path: PauseSubState.songName, type: 'MUSIC'});
		else if (ClientPrefs.pauseMusic != 'None')
			shitToLoad.push({path: Paths.formatToSongPath(ClientPrefs.pauseMusic), type: 'MUSIC'}); 
		shitToLoad.push({path: "breakfast", type: 'MUSIC'}); 
		*/

		////
		if (ClientPrefs.noteSkin == 'Quants'){
			shitToLoad.push({path: 'QUANT$arrowSkin'});
			shitToLoad.push({path: 'QUANT$splashSkin'});
		}else{
			shitToLoad.push({path: arrowSkin});
			shitToLoad.push({path: splashSkin});
		}

		////
		if (stageData.preloadStrings != null)
		{
			var lib = stageData.directory.trim().length > 0 ? stageData.directory : null;
			for (i in stageData.preloadStrings)
				shitToLoad.push({path: i, library: lib});
		}

		if (stageData.preload != null)
		{
			for (i in stageData.preload)
				shitToLoad.push(i);
		}

		var characters:Array<String> = [SONG.player1, SONG.player2];
		if (!stageData.hide_girlfriend)
		{
			characters.push(SONG.gfVersion);
		}

        #if PE_MOD_COMPATIBILITY
        for (section in PlayState.SONG.notes)
		{
            var garbage:Array<Array<Dynamic>> = [];
            
            var idx = section.sectionNotes.length-1;
			while(idx > 0)
			{
                var songNotes = section.sectionNotes[idx];
                if(songNotes[1] <= -1){
                    SONG.events.push([
						songNotes[0],
                        [
                            [
                                songNotes[2],
                                songNotes[3],
                                songNotes[4]
                            ]
                        ]
					]);
                    section.sectionNotes.splice(idx, 1);
                }
                idx--;
            }
        }
        #end

		for (character in characters)
		{
			for (data in CharacterData.returnCharacterPreload(character))
				shitToLoad.push(data);
		}

		for (event in getEvents())
		{
			for (data in preloadEvent(event))
			{ // preloads everythin for events
				if (!shitToLoad.contains(data))
					shitToLoad.push(data);
			}
		}

		for (track in songTrackNames){
			shitToLoad.push({
				path: '$songName/$track',
				type: 'SONG'
			});
		}

		Paths.getAllStrings();
		Cache.loadWithList(shitToLoad);
		shitToLoad = [];

		//// Asset precaching end

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		splash.alpha = 0.0;

		grpNoteSplashes.cameras = [camHUD];
		grpNoteSplashes.add(splash);

		//// Characters

		var gfVersion:String = SONG.gfVersion;

		if (stageData.hide_girlfriend != true)
		{
			gf = new Character(0, 0, gfVersion);

			if (stageData.camera_girlfriend != null){
				gf.cameraPosition[0] += stageData.camera_girlfriend[0];
				gf.cameraPosition[1] += stageData.camera_girlfriend[1];
			}

            gf.setDefaultVar("used", true);
			startCharacter(gf);
			gf.scrollFactor.set(0.95, 0.95);
			gfMap.set(gf.curCharacter, gf);
			gfGroup.add(gf);
		}

		dad = new Character(0, 0, SONG.player2);

		if (stageData.camera_opponent != null){
			dad.cameraPosition[0] += stageData.camera_opponent[0];
			dad.cameraPosition[1] += stageData.camera_opponent[1];
		}
        dad.setDefaultVar("used", true);
		startCharacter(dad, true);
		
		dadMap.set(dad.curCharacter, dad);
		dadGroup.add(dad);

		boyfriend = new Character(0, 0, SONG.player1, true);
		if (stageData.camera_boyfriend != null){
			boyfriend.cameraPosition[0] += stageData.camera_boyfriend[0];
			boyfriend.cameraPosition[1] += stageData.camera_boyfriend[1];
		}
		boyfriend.setDefaultVar("used", true);
		startCharacter(boyfriend);

		boyfriendMap.set(boyfriend.curCharacter, boyfriend);
		boyfriendGroup.add(boyfriend);

		if(dad.posType == 'gf') {
			dad.setPosition(GF_X, GF_Y);
			if(gf != null)
				gf.visible = false;
		}

		////
		stage.buildStage();

		// in case you want to layer characters or objects in a specific way (like in infimario for example)
		// RICO CAN WE STOP USING SLURS IN THE CODE
		// we???
		// fine, can YOU stop using slurs in the code >:(
		if (Globals.Function_Stop != callOnHScripts("onAddSpriteGroups"))
		{
			add(stage);

			add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);

			add(stage.foreground);
		}

        if (hud == null){
			switch(ClientPrefs.etternaHUD){
				case 'Kade': hud = new KadeHUD(boyfriend.healthIcon, dad.healthIcon, SONG.song, stats);
				case 'Advanced': hud = new AdvancedHUD(boyfriend.healthIcon, dad.healthIcon, SONG.song, stats);
				case 'Vanilla': hud = new VanillaHUD(boyfriend.healthIcon, dad.healthIcon, SONG.song, stats);
				default: 
					hud = HScriptedHUD.fromName(boyfriend.healthIcon, dad.healthIcon, SONG.song, stats, ClientPrefs.etternaHUD);
					if (hud == null){
					trace('customHUD file not exists or its a default hud.');
					hud = new PsychHUD(boyfriend.healthIcon, dad.healthIcon, SONG.song, stats);
					}
			}
		}
		if (!rhythmMode){
		hud.cameras = [camHUD];
		}else{
		hud.cameras = [camRhythmHUD];
		}
		hud.alpha = ClientPrefs.hudOpacity;
		add(hud);

        #if PE_MOD_COMPATIBILITY
		healthBar = hud.getHealthbar();
		if (healthBar != null){
			iconP1 = healthBar.iconP1;
			iconP2 = healthBar.iconP2;
		}
        #end
		if (rhythmMode){
			if (Reflect.hasField(hud,'iconP1'))
			Reflect.field(hud,'iconP1').visible = false;
			if (Reflect.hasField(hud,'iconP2'))
				Reflect.field(hud,'iconP2').visible = false;
		}
		//// Generate playfields so you can actually, well, play the game
		callOnScripts("prePlayfieldCreation"); // backwards compat
        // TODO: add deprecation messages to function callbacks somehow

        callOnScripts("onPlayfieldCreation"); // you should use this

		if (!rhythmMode){
		playfields.cameras = [camHUD];
		notes.cameras = [camHUD];
		}else{
		playfields.cameras = [camRhythmHUD];
		notes.cameras = [camRhythmHUD];
		}
		for (i in 0...curStrum){
			fields[i] = new PlayField(modManager);{
			if (rhythmMode){
			fields[i].cameras = [camRhythmHUD];
			}else{
			fields[i].cameras = [camHUD];
			}
			fields[i].isPlayer = false;
			fields[i].autoPlayed = true;
			fields[i].modNumber = i;
			fields[i].playerId = i;
			fields[i].noteHitCallback = defaultNoteHit;
			}
		}
		playerField = fields[0];
		playerField.characters = [for(ch in boyfriendMap) ch];
		
		playerField.isPlayer = !playOpponent;
		playerField.autoPlayed = !playerField.isPlayer || cpuControlled;
		playerField.noteHitCallback = playOpponent ? opponentNoteHit : goodNoteHit;

		dadField = fields[1];
		dadField.isPlayer = playOpponent;
		dadField.autoPlayed = !dadField.isPlayer || cpuControlled;
		dadField.modNumber = 1;
		dadField.playerId = 1;
		dadField.characters = [for(ch in dadMap) ch];
		dadField.noteHitCallback = playOpponent ? goodNoteHit : opponentNoteHit;

		dad.idleWhenHold = !dadField.isPlayer;
		boyfriend.idleWhenHold = !playerField.isPlayer;

		for (i in fields){
		playfields.add(i);
		initPlayfield(i);
		}
		
		callOnScripts("postPlayfieldCreation"); // backwards compat
        callOnScripts("onPlayfieldCreationPost");

		////
		cameraPoints = [sectionCamera];
		moveCameraSection(SONG.notes[0]);

		////
		ratingGroup = new RatingGroup();
		ratingGroup.cameras = [worldCombos ? camGame : camHUD];
		lastJudge = ratingGroup.lastJudge;

		timingTxt = new FlxText();
		timingTxt.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timingTxt.cameras = ratingGroup.cameras;
		timingTxt.scrollFactor.set();
		timingTxt.borderSize = 1.25;
		
		timingTxt.visible = false;
		timingTxt.alpha = 0;

		// init shit
		health = 1.0;
		reloadHealthBarColors();

		startingSong = true;

		#if LUA_ALLOWED
		//// "GLOBAL" LUA SCRIPTS
		var filesPushed:Array<String> = [];
		for (folder in Paths.getFolders('scripts'))
		{
			Paths.iterateDirectory(folder, function(file:String)
			{
				if(!file.endsWith('.lua') || filesPushed.contains(file))
					return;

				createLua(folder + file);
				filesPushed.push(file);
			});
		}

		//// STAGE LUA SCRIPTS
		var baseFile:String = 'stages/$curStage.lua';
		for (file in [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)])
		{
			if (!Paths.exists(file))
				continue;

			createLua(file);

			break;
		}

		// SONG SPECIFIC LUA SCRIPTS
		var foldersToCheck:Array<String> = Paths.getFolders('songs/$songName');
		#if PE_MOD_COMPATIBILITY
		for (dir in Paths.getFolders('data/$songName'))
			foldersToCheck.push(dir);
		#end

		var filesPushed:Array<String> = [];
		for (folder in foldersToCheck){
			Paths.iterateDirectory(folder, function(file:String)
			{
				if(!file.endsWith('.lua') || filesPushed.contains(file))
					return;

				createLua(folder + file);
				filesPushed.push(file);			
			});
		}
		#end

		// EVENT AND NOTE SCRIPTS WILL GET LOADED HERE
		generateSong(SONG.song);

		var stringId:String = 'difficultyName_$difficultyName';
		displayedDifficulty = Paths.hasString(stringId) ? Paths._getString(stringId) : difficultyName;
		if (metadata != null){
		if (metadata.songNames != null && metadata.songNames.length > 0)	{
			for (songName in metadata.songNames){
				if (songName.lang == Paths.locale)
					displayedSong = songName.name;
			}
		}
		}
		if (displayedSong == null)
			displayedSong = SONG.song;
		

		#if DISCORD_ALLOWED {
		// Discord RPC texts
		stateText = '${displayedSong} ($displayedDifficulty)';
		
		detailsText = isStoryMode ? "Story Mode" : "Freeplay";
		detailsPausedText = "Paused - " + detailsText;

		updateSongDiscordPresence();
		}#end

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		////
		callOnAllScripts('onCreatePost');

		add(ratingGroup);
		add(timingTxt);
		add(playfields);
		add(notefields);
		add(grpNoteSplashes);
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);

		////
		#if !tgt
		if (prevCamFollowPos != null){
			// do nothing
		}else if(SONG.notes[0].mustHitSection)
		{
			var cam = dad.getCamera();
			camFollow.set(cam[0], cam[1]);

			var cam = boyfriend.getCamera();
			sectionCamera.set(cam[0], cam[1]); 
		}
		else if(SONG.notes[0].gfSection && gf != null)
		{
			var cam = boyfriend.getCamera();
			sectionCamera.set(cam[0], cam[1]); 
			
			var cam = gf.getCamera();
			sectionCamera.set(cam[0], cam[1]); 
		}
		else
		{
			var cam = boyfriend.getCamera();
			camFollow.set(cam[0], cam[1]);

			var cam = dad.getCamera();
			sectionCamera.set(cam[0], cam[1]); 
		}
		camFollowPos.setPosition(camFollow.x, camFollow.y);
		#end

		//// nulling them here so stage scripts can use them as a starting camera position
		prevCamFollow = null;
		prevCamFollowPos = null;

		// Load the countdown intro assets!!!!!

		if (hudSkinScript != null && hudSkinScript.exists("introSnds"))
            introSnds = hudSkinScript.get("introSnds");

		if (hudSkinScript != null && hudSkinScript.exists("introAlts"))
			introAlts = hudSkinScript.get("introAlts");

		for (introSndPath in introSnds){
			if (introSndPath != null)
				shitToLoad.push({path: introSndPath, type: "SOUND"});
		}
		for (introImgPath in introAlts){
			if (introImgPath != null)
				shitToLoad.push({path: introImgPath});
		}

		Cache.loadWithList(shitToLoad);
		shitToLoad = [];

        if(gf!=null) gf.callOnScripts("onAdded", [gf, null]); // if you can come up w/ a better name for this callback then change it lol
		// (this also gets called for the characters changed in changeCharacter)
        boyfriend.callOnScripts("onAdded", [boyfriend, null]);
        dad.callOnScripts("onAdded", [dad, null]); 

		super.create();

		RecalculateRating();
		startCountdown();

		finishedCreating = true;

		noteTypeMap.clear();
		noteTypeMap = null;
		eventPushedMap.clear();
		eventPushedMap = null;

		CustomFadeTransition.nextCamera = camOther;
	
		Paths.clearUnusedMemory();
	}

	function setStageData(stageData:StageFile)
	{
		defaultCamZoom = stageData.defaultZoom;

		var color = FlxColor.fromString(stageData.bg_color);
		camGame.bgColor = color != null ? color : FlxColor.BLACK;
		
		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if(stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if(boyfriendCameraOffset == null){ //Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];
			stageData.camera_boyfriend = [0, 0];
		}

		opponentCameraOffset = stageData.camera_opponent;
		if(opponentCameraOffset == null){
			opponentCameraOffset = [0, 0];
			stageData.camera_opponent = [0, 0];
		}

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if(girlfriendCameraOffset == null){
			girlfriendCameraOffset = [0, 0];
			stageData.camera_girlfriend = [0, 0];
		}

		if(boyfriendGroup==null)
			boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		else{
			boyfriendGroup.x = BF_X;
			boyfriendGroup.y = BF_Y;
		}
		if(dadGroup==null)
			dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		else{
			dadGroup.x = DAD_X;
			dadGroup.y = DAD_Y;
		}

		if(gfGroup==null)
			gfGroup = new FlxSpriteGroup(GF_X, GF_Y);
		else{
			gfGroup.x = GF_X;
			gfGroup.y = GF_Y;
		}
	}

	public function addTextToDebug(text:String, ?color:FlxColor = FlxColor.WHITE) {
		luaDebugGroup.forEachAlive(function(spr:DebugText) {
			spr.y += 20;
		});

		if(luaDebugGroup.members.length > 34) {
			var blah = luaDebugGroup.members[34];
			blah.destroy();
			luaDebugGroup.remove(blah);
		}
		luaDebugGroup.insert(0, new DebugText(text, luaDebugGroup));
	}

	public function reloadHealthBarColors() {
        var dadColor:FlxColor = FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]);
		var bfColor:FlxColor = FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]);
		if(callOnHScripts('reloadHealthBarColors', [hud, dadColor, bfColor]) == Globals.Function_Stop)
			return;

		hud.reloadHealthBarColors(dadColor, bfColor);
	}

	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					newBoyfriend.cameraPosition[0] += stageData.camera_boyfriend[0];
					newBoyfriend.cameraPosition[1] += stageData.camera_boyfriend[1];

					newBoyfriend.alpha = 0.00001;
					if(playerField!=null)
						playerField.characters.push(newBoyfriend);

					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);

					startCharacter(newBoyfriend);

                    newBoyfriend.setOnScripts("used", false); // used to determine when a character is actually being used
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					newDad.cameraPosition[0] += stageData.camera_opponent[0];
					newDad.cameraPosition[1] += stageData.camera_opponent[1];
					if(dadField!=null)
						dadField.characters.push(newDad);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacter(newDad, true);
					newDad.alpha = 0.00001;

					newDad.setOnScripts("used", false); // used to determine when a character is actually being used
				}

			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.cameraPosition[0] += stageData.camera_girlfriend[0];
					newGf.cameraPosition[1] += stageData.camera_girlfriend[1];
					newGf.scrollFactor.set(0.95, 0.95);

					newGf.alpha = 0.00001;

					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacter(newGf);

					newGf.setOnScripts("used", false); // used to determine when a character is actually being used

				}
		}
	}

	function startCharacter(char:Character, gf:Bool=false){
		startCharacterPos(char, gf);
		startCharacterScript(char);
	}

	function startCharacterScript(char:Character)
	{
		char.startScripts();

        for(script in char.characterScripts){
            #if LUA_ALLOWED
            if((script is FunkinLua))
                luaArray.push(cast script);
            else
            #end
            hscriptArray.push(cast script);

            funkyScripts.push(script);
        }
	}

	public function getLuaObject(tag:String, ?checkForTextsToo:Bool){
		if (modchartObjects.exists(tag)) return modchartObjects.get(tag);
		if (modchartSprites.exists(tag)) return modchartSprites.get(tag);
		if (checkForTextsToo==true && modchartTexts.exists(tag)) return modchartTexts.get(tag);
		return null;
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false, ?startBopBeat:Float=-5) {
		if(gfCheck && char.posType == 'gf') { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
        char.nextDanceBeat = startBopBeat;
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	var curVideo:VideoHandler = null;
	public function startVideo(name:String):VideoHandler
	{
		#if !VIDEOS_ALLOWED
		inCutscene = true;

		FlxG.log.warn('Video not supported!');
		startAndEnd();
		return null;
		#else

		var filepath:String = Paths.video(name);
		if (!Paths.exists(filepath))
		{
			FlxG.log.warn('Couldnt find video file: ' + name);
			startAndEnd();
			return null;
		}
		var video:VideoHandler = curVideo = new VideoHandler();
        #if (hxvlc)
        video.load(filepath);
		video.onEndReached.add(() ->
		{
            video.dispose();
			if (FlxG.game.contains(video))
				FlxG.game.removeChild(video);
			if (curVideo == video)
				curVideo = null;
            startAndEnd();
		});
        video.play();
		#elseif (hxCodec >= "3.0.0")
		video.play(filepath);
		video.onEndReached.add(()->{
			video.dispose();

			if (curVideo == video)
				curVideo = null;
			startAndEnd();
		}, true);
		#else
		video.playVideo(filepath);
		video.finishCallback = startAndEnd;
		#end

		return video;
		#end
	}

	function startAndEnd()
	{
		if(endingSong){
			endSong();
		}
		else{
			startCountdown();
		}
	}

	/*
	function songIntroCutscene(){
		if (isStoryMode && !seenCutscene)
		{
			switch (songName)
			{
				default:
					startCountdown();
			}
			seenCutscene = true;
		}
		else
		{
			startCountdown();
		}
	}
	*/

	public function startCountdown():Void
	{
		if(startedCountdown) {
			callOnScripts('onStartCountdown');
			callScript(hudSkinScript, "onStartCountdown");
			return;
		}

		inCutscene = false;

		if (hudSkinScript != null){
			if (callScript(hudSkinScript, "onStartCountdown") == Globals.Function_Stop)
                return;
        }

		if (callOnScripts('onStartCountdown') == Globals.Function_Stop){
			return;
		}

		if (skipCountdown || startOnTime > 0)
			skipArrowStartTween = true;

		callOnScripts('preReceptorGeneration'); // backwards compat, deprecated
		callOnScripts('onReceptorGeneration');

		for(field in playfields.members)
			field.generateStrums();

		callOnScripts('postReceptorGeneration'); // deprecated
		callOnScripts('onReceptorGenerationPost');

		for(field in playfields.members)
			field.fadeIn(isStoryMode || skipArrowStartTween); // TODO: check if its the first song so it should fade the notes in on song 1 of story mode

		callOnScripts('preModifierRegister'); // deprecated
		if (callOnScripts('onModifierRegister') != Globals.Function_Stop) {
			modManager.registerDefaultModifiers();

			#if !tgt
			if (midScroll) {
				var off:Float = Math.min(FlxG.width, 1280) / 4;
				var opp:Int = playOpponent ? 0 : 1;
				
				var halfKeys:Int = Math.floor(keyCount / 2);
				if (keyCount % 2 != 0) // middle receptor dissappears, if there is one
					modManager.setValue('alpha${halfKeys + 1}', 1.0, opp);
				
				for (i in 0...halfKeys)
					modManager.setValue('transform${i}X', -off, opp);
				for (i in keyCount-halfKeys...keyCount)
					modManager.setValue('transform${i}X', off, opp);
	
				modManager.setValue("alpha", 0.6, opp);
				modManager.setValue("opponentSwap", 0.5);
			}
			#end
		}
		callOnScripts('postModifierRegister'); // deprecated
		callOnScripts('onModifierRegisterPost');
		startedCountdown = true;
		setOnScripts('startedCountdown', true);
		callOnScripts('onCountdownStarted');
		if (hudSkinScript != null)
			hudSkinScript.call("onCountdownStarted");

		callOnScripts("generateModchart"); // this is where scripts should generate modcharts from here on out lol

		if (startOnTime != 0 || skipCountdown) {
			trace('starting on time: $startOnTime, skipping countdown: $skipCountdown');
			startSong();
			return;
		}

		// Do the countdown.
		//var swagCounter:Int = 0;
		var countdown = new funkin.objects.Countdown(this);
		resetCountdown(countdown);
		if (rhythmMode) countdown.cameras = [camRhythmHUD];
		countdown.start(Conductor.crochet * 0.001); // time is optional but here we are
		curCountdown = countdown;
		//startTimer = new FlxTimer();
		//startTimer.start(
		//	Conductor.crochet * 0.001,
		//	(tmr)->{
		//		countdownTick(swagCounter);
		//		swagCounter++;
		//	},
		//	5
		//);
	}

	public function resetCountdown(countdown:funkin.objects.Countdown):Void {
		if (countdown == null) return;
		// I don't wanna break scripts so if you have a better way, do it
		if (countdown.introAlts != introAlts) countdown.introAlts = introAlts;
		if (countdown.introSnds != introSnds) countdown.introSnds = introSnds;
		if (countdown.introSoundsSuffix != introSoundsSuffix) countdown.introSoundsSuffix = introSoundsSuffix;
		countdown.onTick = (pos: Int) -> {
			countdownSpr = countdown.sprite;
			countdownSnd = countdown.sound;
			countdownTwn = countdown.tween;
		}
		//
	}

	function checkCharacterDance(character:Character, ?beat:Float, ignoreBeat:Bool = false){
        if(character.danceEveryNumBeats == 0)return;
        if(character.animation.curAnim == null)return;
        if(beat == null)
            beat = this.curDecBeat;


        
        var shouldBop = beat >= character.nextDanceBeat;
        if (shouldBop || ignoreBeat){
            if (shouldBop)
                character.nextDanceBeat += character.danceEveryNumBeats;

			if (!character.animation.curAnim.name.startsWith("sing") && !character.stunned) 
                character.dance();
        }
        
    }

	function danceCharacters(?curBeat:Float)
	{
		final curBeat = curBeat==null ? this.curDecBeat : curBeat;

		for (char in gfGroup.members){
			if ((char is Character)){
			var girlfriend:Character = cast char;
			checkCharacterDance(girlfriend, curBeat);
			}
		}

		for (field in playfields)
		{
			for (char in field.characters)
			{
				if (char != gf)
					checkCharacterDance(char, curBeat);
				
			}
		}
	}

	public function addBehindGF(obj:FlxObject)
	{
		insert(members.indexOf(gfGroup), obj);
	}
	public function addBehindBF(obj:FlxObject)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}
	public function addBehindDad(obj:FlxObject)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var time = time + 350;

		var i:Int = allNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = allNotes[i];
			if(daNote.strumTime < time)
			{
				daNote.ignoreNote = true;
				if (modchartObjects.exists('note${daNote.ID}'))
					modchartObjects.remove('note${daNote.ID}');
				for (field in playfields)
					field.removeNote(daNote);

				camZooming = true;
			}
			--i;
		}
	}

	public function setSongTime(time:Float)
	{
		if(time < 0) time = 0;

		if (curCountdown != null && !curCountdown.finished)
			curCountdown.destroy();

		inst.pause();
		if (vocals != null)
		vocals.pause();
		for (track in tracks)
			track.pause();

		////
		inst.time = time;
		inst.volume = 1;
		inst.play();
		if (vocals != null){
		vocals.time = time;
		vocals.volume = 1;
		vocals.play();
		}
		for (track in tracks){
			track.time = time;
			track.play();
		}
		if (backGroundVideo!= null && backGroundVideo.bitmap != null && backGroundVideo.bitmap.bitmapData != null)
			backGroundVideo.bitmap.time = Std.int(time);
		Conductor.songPosition = time;
		songTime = time;
	}

	var previousFrameTime:Int = 0;
	var songTime:Float = 0;
	var vocalsEnded:Bool = false;
	function startSong():Void
	{
		startingSong = false;

		previousFrameTime = FlxG.game.ticks;

		inst.onComplete = function(){
			trace("song ended!?");
			finishSong(false);
		};

		var startOnTime = PlayState.startOnTime;

		if (startOnTime != 0){
			startOnTime = startOnTime > 500 ? startOnTime - 500 : 0;
            startedOnTime = startOnTime;
			PlayState.startOnTime = 0;
			clearNotesBefore(startOnTime + 500);
		}

		Conductor.songPosition = startOnTime;

		for (track in tracks)
			track.play(false, startOnTime);

		if (paused) {
			trace('Oopsie doopsie! Paused sound');
			for (track in tracks)
				track.pause();
		}
		if (rhythmMode){
			if (backGroundVideo != null){
				backGroundVideo.play();
				
			}
		}
		// Song duration in a float, useful for the time left feature
		songLength = inst.length;
		hud.songLength = songLength;
		hud.songStarted();

		resyncVocals();
		
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');
	}

	private var noteTypeMap:Map<String, Bool> = new Map<String, Bool>();
	private var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();

	function shouldPush(event:EventNote){
		switch(event.event){
			default:
				if (eventScripts.exists(event.event))
				{
					var eventScript:FunkinScript = eventScripts.get(event.event);
					var returnVal:Dynamic = callScript(eventScript, "shouldPush", [event]);

					if (returnVal == Globals.Function_Stop) returnVal = false;

					return !(returnVal == false);
				}
		}
		return true;
	}

	function eventSort(a:Array<Dynamic>, b:Array<Dynamic>)
		return Std.int(a[0] - b[0]);

	function getEvents():Array<EventNote>
	{
		var songData = SONG;
		var events:Array<EventNote> = [];

		var eventsJSON = Song.loadFromJson('events', '', songName, false);
		if (eventsJSON != null) {
			eventsJSON = Song.onLoadEvents(eventsJSON);
			var rawEventsData:Array<Array<Dynamic>> = eventsJSON.events;
			rawEventsData.sort(eventSort);

			var eventsData:Array<Array<Dynamic>> = [];
			for (event in rawEventsData){
				var last = eventsData[eventsData.length-1];
				
				if (last != null && Math.abs(last[0] - event[0]) <= Conductor.stepCrochet / (192 / 16)){
					var fuck:Array<Array<Dynamic>> = event[1];
					for (shit in fuck) eventsData[eventsData.length - 1][1].push(shit);
				}else
					eventsData.push(event);
			}

			for (event in eventsData) //Event Notes
			{
				var eventTime:Float = event[0] + ClientPrefs.noteOffset;
				var subEvents:Array<Dynamic> = event[1];
	
				for (eventData in subEvents)
				{
					var eventNote:EventNote = {
						strumTime: eventTime,
						event: eventData[0],
						value1: eventData[1],
						value2: eventData[2],
						value3: eventData[3]
					};
					if (shouldPush(eventNote)) events.push(eventNote);
				}
			}
		}

		////
		var rawEventsData:Array<Array<Dynamic>> = songData.events;
		rawEventsData.sort(eventSort);
		var eventsData:Array<Array<Dynamic>>  = [];

		for (event in rawEventsData){
			var last = eventsData[eventsData.length-1];

			if (last != null && Math.abs(last[0] - event[0]) <= Conductor.stepCrochet / (192 / 16)){
				var fuck:Array<Array<Dynamic>> = event[1];
				for (shit in fuck) eventsData[eventsData.length - 1][1].push(shit);
			}else
				eventsData.push(event);
		}

		songData.events = eventsData;		

		for (event in songData.events) //Event Notes
		{
			var eventTime:Float = event[0] + ClientPrefs.noteOffset;
			var subEvents:Array<Dynamic> = event[1];

			for (eventData in subEvents)
			{
				var eventNote:EventNote = {
					strumTime: eventTime,
					event: eventData[0],
					value1: eventData[1],
					value2: eventData[2],
					value3: eventData[3]
				};
				if (shouldPush(eventNote)) events.push(eventNote);
			}
		}

		return events;
	}

	private function generateSong(dataPath:String):Void
	{
		Conductor.changeBPM(PlayState.SONG.bpm);

		////
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype', songSpeedType);

		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', SONG.speed);
		}

		songSpeed *= FlxG.height / 720; // Adjust speed to game size

		////
		#if tgt if(ClientPrefs.ruin){
			AL.effecti(sndEffect, AL.EFFECT_TYPE, AL.EFFECT_REVERB);
			AL.effectf(sndEffect, AL.REVERB_DECAY_TIME, 5);
			AL.effectf(sndEffect, AL.REVERB_GAIN, 0.75);
			AL.effectf(sndEffect, AL.REVERB_DIFFUSION, 0.5);
		}else #end {
			AL.effecti(sndEffect, AL.EFFECT_TYPE, AL.EFFECT_NULL);
			AL.filteri(sndFilter, AL.FILTER_TYPE, AL.FILTER_NULL);
		}

		////
		for (trackName in songTrackNames) {
			var newTrack = new FlxSound().loadEmbedded(Paths.track(PlayState.SONG.song, trackName));
			//newTrack.volume = 0.0;
			newTrack.pitch = playbackRate;
			newTrack.filter = sndFilter;
			newTrack.effect = sndEffect;
			newTrack.context = MUSIC;
			newTrack.exists = true; // So it doesn't get recycled
			FlxG.sound.list.add(newTrack);
			
			trackMap.set(trackName, newTrack);
			tracks.push(newTrack);
		}

		inline function getTrackInstances(nameArray:Null<Array<String>>)
			return nameArray==null ? [] : [for (name in nameArray) trackMap.get(name)];

		instTracks = getTrackInstances(SONG.tracks.inst);
		playerTracks = getTrackInstances(SONG.tracks.player);
		opponentTracks = getTrackInstances(SONG.tracks.opponent);

		inst = instTracks[0];
		vocals = playerTracks[0];
		
		//// NEW SHIT
		var noteData:Array<SwagSection> = PlayState.SONG.notes;
		add(notes);

		// loads note types
		for (section in noteData)
		{
			for (songNotes in section.sectionNotes)
			{
				var type:Dynamic = songNotes[3];
				/*
				if (Std.isOfType(type, Int)) 
					type = editors.ChartingState.noteTypeList[type];
				*/

				if (!noteTypeMap.exists(type)) {
					firstNotePush(type);
					noteTypeMap.set(type, true);
				}
			}
		}

		#if (LUA_ALLOWED && PE_MOD_COMPATIBILITY)
		var luaNotetypeScripts = [];
		#end
		for (notetype in noteTypeMap.keys())
		{
			var doPush:Bool = false;
			for(file in ["notetypes", #if PE_MOD_COMPATIBILITY "custom_notetypes" #end])
			{
				var baseScriptFile:String = '$file/$notetype';
				for (ext in Paths.SCRIPT_EXTENSIONS)
				{
					if (doPush)
						break;
					var baseFile = '$baseScriptFile.$ext';
					var files = [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)];
					for (file in files)
					{
						if (!Paths.exists(file))
							continue;

						#if LUA_ALLOWED
						if (Paths.LUA_EXTENSIONS.contains(ext))
						{
							var script = createLua(file, notetype, #if PE_MOD_COMPATIBILITY true #else false #end);
							#if PE_MOD_COMPATIBILITY
							// PE_MOD_COMPATIBILITY to call onCreate at the end of this function
							luaNotetypeScripts.push(script);
							#end
							doPush = true;
						}
						else if (Paths.HSCRIPT_EXTENSIONS.contains(ext)) #end
						{
							notetypeScripts.set(notetype, createHScript(file, notetype));
							doPush = true;
						}
						
						if (doPush)
							break;
					}
				}
			}
		}

		//// load events
		var daEvents:Array<EventNote> = getEvents();
		for (event in daEvents)
			eventPushedMap.set(event.event, true);

		for (event in eventPushedMap.keys())
		{
			var doPush:Bool = false;

			for(file in ["events", #if PE_MOD_COMPATIBILITY "custom_events" #end]){
				var baseScriptFile:String = '$file/$event';
				for (ext in Paths.SCRIPT_EXTENSIONS)
				{
					if (doPush)
						break;
					var baseFile = '$baseScriptFile.$ext';
					var files = [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)];
					for (file in files)
					{
						if (!Paths.exists(file))
							continue;

						#if LUA_ALLOWED
						if (Paths.LUA_EXTENSIONS.contains(ext))
						{
							// psych lua scripts work the exact same no matter what type of script they are 
							createLua(file, event);
							doPush = true;
						}
						else #end if (Paths.HSCRIPT_EXTENSIONS.contains(ext))
						{
							var script = createHScript(file, event);
							eventScripts.set(event, script);
							script.call("onLoad");
							doPush = true;
						}
						if (doPush)
							break;
					}
				}
			}

			firstEventPush(event);
		}

		for (subEvent in daEvents)
			subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
		
        if(daEvents.length > 1)
            daEvents.sort(sortByTime);

		for (subEvent in daEvents) {
			eventNotes.push(subEvent);
			eventPushed(subEvent);
		}

		if (eventNotes.length > 1)
			eventNotes.sort(sortByTime);

		generateNotes(PlayState.SONG); // generates the chart

		speedChanges.sort(svSort);

		allNotes.sort(sortByNotes);

		for(fuck in allNotes)
			unspawnNotes.push(fuck);
		
		
		for (field in playfields.members)
			field.clearStackedNotes();


		#if (LUA_ALLOWED && PE_MOD_COMPATIBILITY)
		for (script in luaNotetypeScripts)
			script.call("onCreate");
		luaNotetypeScripts = null;
		#end
		checkEventNote();
		generatedMusic = true;
	}

	public function generateNotes(songData:SwagSong, callScripts:Bool = true, addToFields:Bool = true, ?playfields:Array<PlayField>, ?notes:Array<Note>){

        if(playfields == null)
            playfields = this.playfields.members;

        if(notes==null)
            notes = allNotes;
        var noteData = songData.notes;
		for (section in noteData) {
			for (songNotes in section.sectionNotes) {
				var daStrumTime:Float = songNotes[0];
				var fuckYOU = songNotes[1];
					if (!songData.igorAutoFix){
					if (!section.mustHitSection){
						if (fuckYOU < keyCount*2){
						if (fuckYOU >= keyCount)
							{
								fuckYOU -= keyCount;
							}
							else
							{
								fuckYOU += keyCount;
							}
						}
					}
					}
				var daColumn:Int = Std.int(fuckYOU % keyCount);
				var daStrum:Int = Math.floor(fuckYOU / keyCount) % curStrum;
				if (songNotes[1] <= -1)
					continue; // RETARDED EVENT NOTES IN OLD PSYCH CHARTS
				// TODO: AUTO CONVERT TO EVENTNOTES

				var gottaHitNote:Bool = section.mustHitSection;

				//if (songNotes[1] % keyCount*2 > 3)
					gottaHitNote = (daStrum == currentPlayerStrum);

				var oldNote:Note;
				if (notes.length > 0)
					oldNote = notes[Std.int(notes.length - 1)];
				else
					oldNote = null;

				var type:Dynamic = songNotes[3];

				if (type == true) // ??????????????????
					type = 1;
				if (Std.isOfType(type, Int)) // Backward compatibility + compatibility with Week 7 charts;
					type = ChartingState.noteTypeList[type];

				var swagNote:Note = new Note(daStrumTime, daColumn, oldNote, gottaHitNote, songNotes[2] > 0 ? HEAD : TAP, false, hudSkin);
                swagNote.realColumn = songNotes[1];
				swagNote.sustainLength = songNotes[2];
				if (swagNote.frames == null){
					swagNote.reloadNote('','NOTE_assets','');
				}
				swagNote.gfNote = (section.gfSection && (songNotes[1] < keyCount));

				swagNote.ID = notes.length;
                swagNote.noteType = type;

                var playfield:PlayField = null;

				if (swagNote.field != null)
					playfield = swagNote.field;
				else
                {
                    if (swagNote.fieldIndex == -1){
						switch (daStrum){
							default:
							swagNote.fieldIndex = daStrum;
						}
					}

					if (playfields[swagNote.fieldIndex] != null)
						playfield = playfields[swagNote.fieldIndex];
                }

                if (playfield == null && playfields.length > 0){
                    swagNote.destroy();
                    continue;
                }

				modchartObjects.set('note${swagNote.ID}', swagNote);
                swagNote.field = playfield;

                if (callScripts)
					callOnScripts("onGeneratedNote", [swagNote]);
				
				playfield = swagNote.field;
				swagNote.fieldIndex = playfield.modNumber;
                
                notes.push(swagNote); // just for the sake of convenience

                if (addToFields)
                    if (playfield != null)
                        playfield.queue(swagNote); // queues the note to be spawned

                if (callScripts)
					callOnScripts("onGeneratedNotePost", [swagNote]);
				
				oldNote = swagNote;
				
				inline function makeSustain(susNote:Int, susPart) {
					var sustainNote:Note = new Note(daStrumTime + Conductor.stepCrochet * (susNote + 1), daColumn, oldNote, gottaHitNote, susPart, false, hudSkin);
					sustainNote.gfNote = swagNote.gfNote;
                    if (callScripts) callOnScripts("onGeneratedHold", [sustainNote]);
					sustainNote.noteType = type;
                    if (sustainNote.frames == null){
						sustainNote.reloadNote('','NOTE_assets','');
					}
					sustainNote.ID = notes.length;
					modchartObjects.set('note${sustainNote.ID}', sustainNote);

					swagNote.tail.push(sustainNote);
					swagNote.unhitTail.push(sustainNote);
					sustainNote.parent = swagNote;
					sustainNote.fieldIndex = swagNote.fieldIndex;
                    sustainNote.field = swagNote.field;

                    if(addToFields)
                        if (playfield != null) 
					        playfield.queue(sustainNote);

					notes.push(sustainNote);

					if (callScripts)callOnScripts("onGeneratedHoldPost", [swagNote]);

					oldNote = sustainNote;
				}

				var susLength = Math.round(swagNote.sustainLength / Conductor.stepCrochet) - 1;
				if (susLength > 0){
					for (susNote in 0...susLength)
						makeSustain(susNote, PART);
					makeSustain(susLength, END);
				}
			}
		}
    

        return notes;
    }

	// everything returned here gets preloaded by the preloader up-top ^
	function preloadEvent(event:EventNote):Array<AssetPreload>{
		var preload:Array<AssetPreload> = [];

		switch(event.event){
			case "Change Character":
				return CharacterData.returnCharacterPreload(event.value2);
		}

		return preload;
	}

	public function getNoteInitialTime(time:Float)
	{
		var event:SpeedEvent = getSV(time);
		return getTimeFromSV(time, event);
	}

	function ease(e:EaseFunction, t:Float, b:Float, c:Float, d:Float)
	{ // elapsed, begin, change (ending-beginning), duration
		var time = t / d;
		return c * e(time) + b;
	}

	public inline function getTimeFromSV(time:Float, event:SpeedEvent){

		// TODO: make easing SVs work somehow

		//if(time >= event.songTime || event.songTime == event.startTime) // practically the same start and end time
			return event.position + (modManager.getBaseVisPosD(time - event.songTime, 1) * event.speed);
/* 		else{
			// ease(easeFunc, passed, startVal, change, length)
			// var passed = curStep - executionStep;
			// var change = endVal - startVal;
			if(event.startSpeed==null)event.startSpeed = currentSV.speed;

			var speed = ease(FlxEase.linear, time - event.songTime, event.startSpeed, event.speed - event.startSpeed, event.songTime - event.startTime);
			trace(speed);
			return event.position + (modManager.getBaseVisPosD(time - event.startTime, 1) * speed);
		} */
	}

	public function getSV(time:Float){
		var event:SpeedEvent = {
			position: 0,
			songTime: 0,
			startTime: 0,
			startSpeed: 1,
			speed: 1
		};
		for (shit in speedChanges)
		{
			if (shit.startTime <= time && shit.startTime >= event.startTime){
				if(shit.startSpeed == null)
					shit.startSpeed = event.speed;
				event = shit;
				
			}
		}

		return event;
	}

	function eventNoteEarlyTrigger(event:EventNote):Float {
		var ret:Dynamic = callOnAllScripts('eventEarlyTrigger', [event.event, event.value1, event.value2, event.value3]);
		if (ret != null && (ret is Int || ret is Float))
			return ret;
		
		if (eventScripts.exists(event.event)){
			var ret:Dynamic = callScript(eventScripts.get(event.event), "getOffset", [event]);
			if (ret != null && (ret is Int || ret is Float))
				return ret;
		}

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}
	
	// called for every event note
	function eventPushed(event:EventNote) 
	{
		if (event.value1 == null) event.value1 = '';
		if (event.value2 == null) event.value2 = '';
		if (event.value3 == null) event.value3 = '';
		switch(event.event)
		{
			case 'Change Scroll Speed': // Negative duration means using the event time as the tween finish time
				var duration = Std.parseFloat(event.value2);
				if (!Math.isNaN(duration) && duration < 0.0){
					event.strumTime -= duration * 1000;
					event.value2 = Std.string(-duration);
				}

			case 'Mult SV' | 'Constant SV':
				var speed:Float = 1;
				if(event.event == 'Constant SV'){
					var b = Std.parseFloat(event.value1);
					speed = Math.isNaN(b) ? songSpeed : (songSpeed / b);
				}else{
					speed = Std.parseFloat(event.value1);
					if (Math.isNaN(speed)) speed = 1;
				}

				speedChanges.push({
					position: getTimeFromSV(event.strumTime, speedChanges[speedChanges.length - 1]),
					songTime: event.strumTime,
					startTime: event.strumTime,
					speed: speed
				});
				
			case 'Change Character':
				var charType:Int = 0;
				switch(event.value1.toLowerCase()) {
					case 'gf' | 'girlfriend' | '2':
						charType = 2;
					case 'dad' | 'opponent' | '1':
						charType = 1;
					default:
						charType = Std.parseInt(event.value1);
						if(Math.isNaN(charType)) charType = 0;
				}
				
				//trace(event.value2, charType);

				addCharacterToList(event.value2, charType);
			default:
				if (eventScripts.exists(event.event))
					callScript(eventScripts.get(event.event), "onPush", [event]);
		}

		callOnHScripts("eventPushed", [event]);
	}

	// called only once for each different event
	function firstEventPush(eventName:String){

		/* onLoad is called on script creation soo...
		switch (eventName)
		{
			default:
				// should PROBABLY turn this into a function, callEventScript(eventNote, "func") or something, idk
				if (eventScripts.exists(eventName))
					eventScripts.get(eventName).call("onLoad");
		}
		*/

		callOnHScripts("firstEventPush", [eventName]);
	}

	function firstNotePush(type:String){
		switch(type){
			default:
				if (notetypeScripts.exists(type))
					callScript(notetypeScripts.get(type), "onLoad", []);
		}
	}

	public function optionsChanged(options:Array<String>){
		if (options.length < 1)
			return;
		
		trace("changed " + options);

		for(note in allNotes)
			note.updateColours();
			
		hud.changedOptions(options);
		
		if(options.contains("gradeSet"))
			ratingStuff = Highscore.grades.get(ClientPrefs.gradeSet);

		if (!ClientPrefs.simpleJudge) {
			for (prevCombo in lastCombos)
				prevCombo.kill();
		}
		
		callOnScripts('optionsChanged', [options]);
		if (hudSkinScript != null) callScript(hudSkinScript, "optionsChanged", [options]);
		
		var reBind:Bool = false;
		for(opt in options){
			if(opt.startsWith("bind")){
				reBind = true;
				break;
			}
		}

		if (!ClientPrefs.coloredCombos)
			comboColor = 0xFFFFFFFF;
		
		for(field in playfields){
			field.noteField.optimizeHolds = ClientPrefs.optimizeHolds;
			field.noteField.drawDistMod = ClientPrefs.drawDistanceModifier;
			field.noteField.holdSubdivisions = Std.int(ClientPrefs.holdSubdivs) + 1;
		}
		
		if(reBind){
			debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
			debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));
			debugKeysBotplay = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('botplay'));

			keysArray = [
				ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_left')),
				ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_down')),
				ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_up')),
				ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_right'))
			];

			// unpress everything
			for (field in playfields.members)
			{
				if (field.inControl && !field.autoPlayed && field.isPlayer)
				{
					for (idx in 0...field.keysPressed.length)
						field.keysPressed[idx] = false;

					for (obj in field.strumNotes)
					{
						obj.playAnim("static");
						obj.resetAnim = 0;
					}
				}
			}
		}
	}

	override function draw(){
		if((subState is GameOverSubstate))
			camStageUnderlay.bgColor = 0;
		else
			camStageUnderlay.bgColor = Math.floor(0xFF * ClientPrefs.stageOpacity) * 0x1000000;

        var ret:Dynamic = callOnScripts('onStateDraw');
		if (ret != Globals.Function_Stop) 
		    super.draw();

        callOnScripts('onStateDrawPost');
	}

	function sortByZIndex(Obj1:{zIndex:Float}, Obj2:{zIndex:Float}):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.zIndex, Obj2.zIndex);
	}

    function sortByNotes(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function sortByTime(Obj1:{strumTime:Float}, Obj2:{strumTime:Float}):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function svSort(Obj1:SpeedEvent, Obj2:SpeedEvent):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.startTime, Obj2.startTime);
	}

	public var skipArrowStartTween:Bool = false; //for lua
	private function generateStaticArrows(player:Int):Void
	{

	}

	override function openSubState(SubState:FlxSubState)
	{
		super.openSubState(SubState);
	}

	#if DISCORD_ALLOWED
	function updateSongDiscordPresence(?detailsText:String)
	{
		final timeLeft:Float = (songLength - Conductor.songPosition - ClientPrefs.noteOffset);
		final detailsText:String = (detailsText!=null) ? detailsText : this.detailsText;

		if (timeLeft > 0.0)
			DiscordClient.changePresence(detailsText, stateText, songName, true, timeLeft);
		else
			DiscordClient.changePresence(detailsText, stateText, songName);
	}
	#else
	// Saves me from having to write #if DISCORD_ALLOWED and blahblah
	inline function updateSongDiscordPresence(?detailsText:String) {}
	#end

	override function closeSubState()
	{
		if (paused)
		{
			resume();
			callOnScripts('onResume');

			hud.alpha = ClientPrefs.hudOpacity;
		}

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		if (!isDead && !paused)
			updateSongDiscordPresence();

		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		#if DISCORD_ALLOWED
		if (!isDead)
			DiscordClient.changePresence(detailsPausedText, stateText, songName);
		#end

		super.onFocusLost();
	}

	public function newPlayfield()
	{
		var field = new PlayField(modManager);
		field.modNumber = playfields.members.length;
        field.playerId = field.modNumber;
		field.cameras = playfields.cameras;
		initPlayfield(field);
		playfields.add(field);
		return field;
	}

	// good to call this whenever you make a playfield
	public function initPlayfield(field:PlayField){
		notefields.add(field.noteField);

		field.judgeManager = judgeManager;

		field.holdPressCallback = stepHold;
        field.holdReleaseCallback = dropHold;

		field.noteRemoved.add((note:Note, field:PlayField) -> {
			if(modchartObjects.exists('note${note.ID}'))modchartObjects.remove('note${note.ID}');
			allNotes.remove(note);
			unspawnNotes.remove(note);
			notes.remove(note);
		});
		field.noteMissed.add((daNote:Note, field:PlayField) -> {
			if (field.isPlayer && !field.autoPlayed && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
				noteMiss(daNote, field);

		});
		field.noteSpawned.add((dunceNote:Note, field:PlayField) -> {
			callOnHScripts('onSpawnNote', [dunceNote]);
			#if LUA_ALLOWED
			callOnLuas('onSpawnNote', [
				allNotes.indexOf(dunceNote),
				dunceNote.column,
				dunceNote.noteType,
				dunceNote.isSustainNote,
				dunceNote.strumTime
			]);
			#end

			notes.add(dunceNote);
			var index:Int = unspawnNotes.indexOf(dunceNote);
			unspawnNotes.splice(index, 1);

			callOnHScripts('onSpawnNotePost', [dunceNote]);
			if (dunceNote.noteScript != null)
				callScript(dunceNote.noteScript, "postSpawnNote", [dunceNote]);
		});
	}

	function resyncVocals():Void
	{
		if(finishTimer != null || transitioning || isDead)
			return;

		if (showDebugTraces)
			trace("resync vocals!!");
		
		for (track in tracks)
			track.pause();

		inst.play();
		Conductor.songPosition = inst.time;

		for (track in tracks){
			//if (Conductor.songPosition < track.length){
				track.time = Conductor.songPosition;
				track.play();
			//}
		}

		updateSongDiscordPresence();
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var resyncTimer:Float = 0;
	var prevNoteCount:Int = 0;

    var svIndex:Int =0;
	override public function update(elapsed:Float)
	{
		if (paused){
			callOnScripts('onUpdate', [elapsed]);
			if (hudSkinScript != null) hudSkinScript.call("onUpdate", [elapsed]);

			super.update(elapsed);

			callOnScripts('onUpdatePost', [elapsed]);
			if (hudSkinScript != null) hudSkinScript.call("onUpdatePost", [elapsed]);

			return;
		}

		////
		for (idx in 0...playfields.members.length)
			playfields.members[idx].noteField.songSpeed = songSpeed;
        
		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);
		
		/*
		for (script in notetypeScripts)
			script.call("onUpdate", [elapsed]); 

		for (script in eventScripts)
			script.call("onUpdate", [elapsed]);

		callOnScripts('onUpdate', [elapsed], null, null, null, null, false);
		*/
		callOnScripts('onUpdate', [elapsed]);
        if (hudSkinScript != null)
            hudSkinScript.call("onUpdate", [elapsed]);

		if (!inCutscene) {
			var xOff:Float = 0;
			var yOff:Float = 0;

			if (ClientPrefs.directionalCam && focusedChar != null){
				xOff = focusedChar.camOffX;
				yOff = focusedChar.camOffY;
			}

			var currentCameraPoint = cameraPoints[cameraPoints.length-1];
			if (currentCameraPoint != null)
				camFollow.copyFrom(currentCameraPoint);

			var lerpVal:Float = Math.exp(-elapsed * 2.4 * cameraSpeed);
			camFollowPos.setPosition(
				FlxMath.lerp(camFollow.x + xOff, camFollowPos.x, lerpVal),
				FlxMath.lerp(camFollow.y + yOff, camFollowPos.y, lerpVal)
			);

			if (!startingSong && !endingSong){
				if (health > healthDrain)
					health -= healthDrain * (elapsed / (1/60));

				/*
				if (boyfriend != null
					&& boyfriend.animation.curAnim != null 
					&& boyfriend.animation.curAnim.name.startsWith('idle')
				) {
					boyfriendIdleTime += elapsed;
					if(boyfriendIdleTime >= 0.15) { // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
						boyfriendIdled = true;
				} else {
					boyfriendIdleTime = 0.0;
				}
				*/
			}
		}

		for (script in notetypeScripts)
			script.call("update", [elapsed]);
		for (script in eventScripts)
			script.call("update", [elapsed]);

		callOnHScripts('update', [elapsed]);

		camOverlay.zoom = camHUD.zoom;
		camOverlay.angle = camHUD.angle;

		////
		if (noteHits.length > 0){
			while (noteHits.length > 0 && (noteHits[0] + 2000) < Conductor.songPosition)
				noteHits.shift();
		}

		stats.nps = nps = Math.floor(noteHits.length / 2);
		FlxG.watch.addQuick("notes per second", nps);
		if (stats.npsPeak < nps)
			stats.npsPeak = nps;

		////
		if (startedCountdown){
			var addition:Float = elapsed * 1000;

			if (inst.playing){
				if(inst.time == Conductor.lastSongPos)
					resyncTimer += addition;
				else
					resyncTimer = 0;
				
				Conductor.songPosition = inst.time + resyncTimer;
				Conductor.lastSongPos = inst.time;

				if (Math.abs(Conductor.songPosition - inst.time) > 30) // uuuhh lollll!!!
					resyncVocals();
				
			}else
				Conductor.songPosition += addition;
			
			////
			if (startingSong){
				if (Conductor.songPosition >= 0)
					startSong();
			}
		}
		
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);		
		
		if (!endingSong){
			//// time travel
			

			if (FlxG.keys.anyJustPressed(debugKeysBotplay))
				cpuControlled = !cpuControlled;

			//// editors
			if (FlxG.keys.anyJustPressed(debugKeysChart))
				openChartEditor();

			else if (FlxG.keys.anyJustPressed(debugKeysCharacter))
			{
				persistentUpdate = false;
				pause();
				cancelMusicFadeTween();
				MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
			}
			
			// RESET = Quick Game Over Screen
			else if (canReset && !inCutscene && startedCountdown && controls.RESET){
				doGameOver();
			}else if (doDeathCheck()){
				// die lol
			}else if (controls.PAUSE && startedCountdown && canPause && !paused)
				openPauseMenu();
		}

		////
        var event:SpeedEvent = speedChanges[svIndex];
		if (svIndex < speedChanges.length - 1){
            while (speedChanges[svIndex + 1] != null && speedChanges[svIndex + 1].startTime <= Conductor.songPosition){
                event = speedChanges[svIndex + 1];
                svIndex++;
            }
        }
		Conductor.visualPosition = getTimeFromSV(Conductor.songPosition, event);
		FlxG.watch.addQuick("visualPos", Conductor.visualPosition);

		checkEventNote();

		super.update(elapsed);
		danceCharacters(); // Update characters dancing
		modManager.update(elapsed, curDecBeat, curDecStep);

		if (generatedMusic)
		{
			keyShit();

			for(field in playfields)
			{
				if (!field.isPlayer)
					continue;
					
				for(char in field.characters)
				{
					if (char.animation.curAnim != null
						&& char.holdTimer > Conductor.stepCrochet * 0.0011 * char.singDuration
						&& char.animation.curAnim.name.startsWith('sing')
						&& !char.animation.curAnim.name.endsWith('miss')
						&& (char.idleWhenHold || !pressedGameplayKeys.contains(true))
					)
                        char.resetDance();
				}
			}
		}

		setOnScripts('cameraX', camFollowPos.x);
		setOnScripts('cameraY', camFollowPos.y);
		
		callOnScripts('onUpdatePost', [elapsed]);
        if (hudSkinScript != null)
            hudSkinScript.call("onUpdatePost", [elapsed]);
	}

	function openChartEditor()
	{
		persistentUpdate = false;
		pause();
		cancelMusicFadeTween();

		if (FlxG.keys.pressed.SHIFT) ChartingState.curSec = curSection;
		MusicBeatState.switchState(new ChartingState());
	}

	public var isDead:Bool = false;
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (
			((skipHealthCheck && instakillOnMiss) || health <= 0)
			&& !(practiceMode || isDead)
		)
		{
			return doGameOver();
		}
		return false;
	}

	function doGameOver()
	{
		switch(callOnScripts('onGameOver')) {
			case Globals.Function_Stop: return false;
			case Globals.Function_Halt: return true;
		} 

		pause();

		isDead = true;
		deathCounter++;
		boyfriend.stunned = true;

		////
		persistentUpdate = false;
		persistentDraw = false;

		if (instaRespawn){
			FlxG.camera.bgColor = 0xFF000000;
			MusicBeatState.resetState(true);
		}else{			
			if (!rhythmMode)
			openSubState(new GameOverSubstate(playOpponent ? dad : boyfriend));
			else
			openSubState(new GameOverSubstateAlt());
			if (rhythmMode){
			FlxTween.tween(camRhythmHUD,{alpha:0},4);
				if (backGroundVideo != null){
					backGroundVideo.pause();
				}
			}
			#if DISCORD_ALLOWED
			// Game Over doesn't get his own variable because it's only used here
			DiscordClient.changePresence("Game Over - " + detailsText, stateText, songName);
			#end
		}

		return true;
	}

	public function checkEventNote() {
		while(eventNotes.length > 0) {
			var daEvent = eventNotes[0];

			if(Conductor.songPosition < daEvent.strumTime)
				break;

			triggerEventNote(daEvent.event, daEvent.value1, daEvent.value2, daEvent.strumTime, daEvent.value3);
			eventNotes.shift();
		}
	}

	public function getControl(key:String) {
		var pressed:Bool = Reflect.getProperty(controls, key);
		//trace('Control result: ' + pressed);
		return pressed;
	}

	function changeCharacter(name:String, charType:Int){
		switch(charType) {
			case 0:
				if(boyfriend.curCharacter != name) {
					trace("turned bf into " + name);
					var shiftFocus:Bool = focusedChar==boyfriend;
					var oldChar = boyfriend;
					if(!boyfriendMap.exists(name)) {
						addCharacterToList(name, charType);
					}

					var lastAlpha:Float = boyfriend.alpha;
					boyfriend.alpha = 0.00001;
					boyfriend = boyfriendMap.get(name);
					boyfriend.alpha = lastAlpha;
					if(shiftFocus)focusedChar=boyfriend;
					//hud.iconP1.changeIcon(boyfriend.healthIcon);
                    //hud.iconChange(1, boyfriend.healthIcon);
                    hud.changedCharacter(1, boyfriend);
                    oldChar.setOnScripts("used", false);
					boyfriend.setOnScripts("used", true);
                    oldChar.callOnScripts("changedOut", [oldChar, boyfriend]); // oldChar, newChar
                    boyfriend.callOnScripts("onAdded", [boyfriend, oldChar]); // if you can come up w/ a better name for this callback then change it lol
                    // (this also gets called for the characters set by the chart's player1/player2)
					

				}
				setOnHScripts('boyfriend', boyfriend);
				setOnScripts('boyfriendName', boyfriend.curCharacter);
			case 1:
				if(dad.curCharacter != name) {
					trace("turned dad into " + name);
					var shiftFocus:Bool = focusedChar==dad;
					var oldChar = dad;
					if(!dadMap.exists(name)) {
						addCharacterToList(name, charType);
					}

					var wasGf:Bool = (dad.posType == 'gf');
					var lastAlpha:Float = dad.alpha;
					dad.alpha = 0.00001;
					dad = dadMap.get(name);
					if(dad.posType != 'gf') {
						if(wasGf && gf != null) {
							gf.visible = true;
						}
					} else if(gf != null) {
						gf.visible = false;
					}
					if(shiftFocus)focusedChar=dad;
					dad.alpha = lastAlpha;
					//hud.iconP2.changeIcon(dad.healthIcon);
					hud.changedCharacter(2, dad);
					oldChar.setOnScripts("used", false);
					dad.setOnScripts("used", true);
					oldChar.callOnScripts("changedOut", [oldChar, dad]); // oldChar, newChar
					dad.callOnScripts("onAdded", [dad, oldChar]); // if you can come up w/ a better name for this callback then change it lol
					// (this also gets called for the characters set by the chart's player1/player2)
					
				}
				setOnHScripts('dad', dad);
				setOnScripts('dadName', dad.curCharacter);

			case 2:
				if(gf != null)
				{
					if(gf.curCharacter != name)
					{
						trace("turned gf into " + name);
						var shiftFocus:Bool = focusedChar==gf;
						var oldChar = gf;
						if(!gfMap.exists(name))
						{
							addCharacterToList(name, charType);
						}

						var lastAlpha:Float = gf.alpha;
						gf.alpha = 0.00001;
						gf = gfMap.get(name);
						gf.alpha = lastAlpha;
						if(shiftFocus)focusedChar=gf;
						hud.changedCharacter(3, gf);
					    oldChar.setOnScripts("used", false);
					    gf.setOnScripts("used", true);
						oldChar.callOnScripts("changedOut", [oldChar, gf]); // oldChar, newChar
                        gf.callOnScripts("onAdded", [gf, oldChar]); // if you can come up w/ a better name for this callback then change it lol
						// (this also gets called for the characters set by the chart's player1/player2)

					}
					setOnHScripts('gf', gf);
					setOnScripts('gfName', gf.curCharacter);
				}
		}
		reloadHealthBarColors();
	}

	public function triggerEventNote(eventName:String = "", value1:String = "", value2:String = "", ?time:Float, value3:String = "") {
        if (time==null)
    		time = Conductor.songPosition;

		if(showDebugTraces)
			trace('Event: ' + eventName + ', Value 1: ' + value1 + ', Value 2: ' + value2 + ', Value 3: ' + value3 + ', at Time: ' + time);

		switch(eventName) {
			case 'Change Focus':
				switch(value1.toLowerCase().trim()){
					case 'dad' | 'opponent':
						if (callOnScripts('onMoveCamera', ["dad"]) != Globals.Function_Stop){
                            whosTurn = 'dad';
							moveCamera(dad);
                        }
					case 'gf':
						if (callOnScripts('onMoveCamera', ["gf"]) != Globals.Function_Stop){
                            whosTurn = 'gf';
							moveCamera(gf);
                        }
					default:
						if (callOnScripts('onMoveCamera', ["bf"]) != Globals.Function_Stop){
                            whosTurn = 'bf';
							moveCamera(boyfriend);
                        }
				}
			case 'Game Flash':
				var dur:Float = Std.parseFloat(value2);
				if(Math.isNaN(dur)) dur = 0.5;

				var col:Null<FlxColor> = FlxColor.fromString(value1);
				if (col == null) col = 0xFFFFFFFF;

				FlxG.camera.flash(col, dur, null, true);
			case 'Hey!':
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				var time:Float = Std.parseFloat(value2);
				if(Math.isNaN(time) || time <= 0) time = 0.6;

				if(value != 0) {
					if(dad.posType == 'gf') { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = time;
					} else if (gf != null) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = time;
					}
				}
				if(value != 1) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = time;
				}

			case 'Set GF Speed':
				var value:Int = Std.parseInt(value1);
				if(Math.isNaN(value) || value < 1) value = 1;
				gfSpeed = value;
			case 'Add Camera Zoom':
				if (ClientPrefs.camZoomP > 0) {
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if(Math.isNaN(camZoom)) camZoom = 0.015;
					if(Math.isNaN(hudZoom)) hudZoom = 0.03;

					cameraBump(camZoom, hudZoom);
				}
			case 'Play Animation':
				//trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch(value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						var val2:Int = Std.parseInt(value2);
						if(Math.isNaN(val2)) val2 = 0;

						switch(val2) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null){
					char.playAnim(value1, true);
					char.specialAnim = true;
				}


			case 'Camera Follow Pos':
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);

				var isNan1 = Math.isNaN(val1);
				var isNan2 = Math.isNaN(val2);

				if (isNan1 && isNan2) 
					cameraPoints.remove(customCamera);
				else{
					if (!isNan1) customCamera.x = val1;
					if (!isNan2) customCamera.y = val2;
					addCameraPoint(customCamera);
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch(value1.toLowerCase()) {
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if(Math.isNaN(val)) val = 0;

						switch(val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}

			case 'Change Character':
				var charType:Int = 0;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				var curChar:Character = boyfriend;
				switch(charType){
					case 2:
						curChar = gf;
					case 1:
						curChar = dad;
					case 0:
						curChar = boyfriend;
				}

				var newCharacter:String = value2;
				var anim:String = '';
				var frame:Int = 0;
				if(newCharacter.startsWith(curChar.curCharacter) || curChar.curCharacter.startsWith(newCharacter)){
					if(curChar.animation!=null && curChar.animation.curAnim!=null){
						anim = curChar.animation.curAnim.name;
						frame = curChar.animation.curAnim.curFrame;
					}
				}

				trace(value2, charType);

				changeCharacter(value2, charType);

                
				if(anim!=''){
					var char:Character = boyfriend;
					switch(charType){
						case 2:
							char = gf;
						case 1:
							char = dad;
						case 0:
							char = boyfriend;
					}

					if(char.animation.getByName(anim)!=null){
						char.playAnim(anim, true);
						char.animation.curAnim.curFrame = frame;
					}
				}

			case 'Change Scroll Speed':
				if (songSpeedType == "constant")
					return;

				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 1.0;
				if(Math.isNaN(val2)) val2 = 0.0;

				var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1.0) * val1;

				// value should never be negative as that should be handled and changed prior to this
				if (val2 == 0.0)
					songSpeed = newValue;
				else{
					songSpeedTween = FlxTween.num(
						this.songSpeed, newValue, val2, 
						{
							ease: FlxEase.linear, 
							onComplete: (twn:FlxTween) -> songSpeedTween = null	
						},
						this.set_songSpeed
					);
				}

			case 'Set Property':
				var value2:Dynamic = switch (value2){
					case "true": true;
					case "false": false;
					default: value2;
				}

				try{
					ScriptingUtil.setProperty(value1, value2);                    
				}catch (e:haxe.Exception){
					trace('Set Property event error: $value1 | $value2');
				}
		}
		callOnScripts('onEvent', [eventName, value1, value2, value3, time]);
		if(eventScripts.exists(eventName))
			callScript(eventScripts.get(eventName), "onTrigger", [value1, value2, value3, time]);
	}

	//// Kinda rewrote the camera shit so that its 'easier' to mod
	public function moveCameraSection(section:SwagSection)
	{
		if (section.gfSection && gf != null){
			if (callOnScripts('onMoveCamera', ["gf"]) != Globals.Function_Stop)
				moveCamera(gf);
		}else if (section.mustHitSection){
			if (callOnScripts('onMoveCamera', ["bf"]) != Globals.Function_Stop)
				moveCamera(boyfriend);
		}else{
			if (callOnScripts('onMoveCamera', ["dad"]) != Globals.Function_Stop)
				moveCamera(dad);
		}
	}
	public function moveCamera(?char:Character)
	{
		focusedChar = char;
		if (char != null){
			var cam = char.getCamera();
			sectionCamera.set(cam[0], cam[1]);
		}
	}

	static public function getCharacterCamera(char:Character) return char.getCamera();

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		var finishCallback:Void->Void = endSong; //In case you want to change it in a specific song.

		hud.updateTime = false;

		for (track in tracks){
			track.volume = 0;
			track.pause();
		}

		////
		if(ClientPrefs.noteOffset <= 0 || ignoreNoteOffset) {
			finishCallback();
		} else {
			finishTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
				finishCallback();
			});
		}
	}

	public function restartSong(noTrans:Bool = false)
	{
		persistentUpdate = false;
		pause();

		if(noTrans)
			FlxTransitionableState.skipNextTransOut = true;

		MusicBeatState.resetState();
	}

	public static function gotoMenus()
	{
		FlxTransitionableState.skipNextTransIn = false;
		CustomFadeTransition.nextCamera = null;

		// MusicBeatState.switchState(new MainMenuState());
		if (isStoryMode){
			MusicBeatState.playMenuMusic(1, true);
			MusicBeatState.switchState(new StoryMenuState());
		}else{
			FreeplayState.comingFromPlayState = true;
			MusicBeatState.switchState(new FreeplayState());
		}
		
		deathCounter = 0;
		seenCutscene = false;
		chartingMode = false;

		if (prevCamFollow != null) prevCamFollow.put();
		if (prevCamFollowPos != null) prevCamFollowPos.destroy();

		if (instance != null){
			instance.cancelMusicFadeTween(); // Doesn't do anything now (?)
			
			instance.camFollow.put();
			instance.camFollowPos.destroy();
		}
	}


	public var transitioning = false;
	public function endSong():Void
	{
		//Should kill you if you tried to cheat
		if(!startingSong) {
			for(field in playfields.members){
				if(field.isPlayer){
					for(daNote in field.spawnedNotes){
						if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
							health -= 0.05 * healthLoss;
						}
					}
				}
			}

			if(doDeathCheck())
				return;
		}

		hud.songEnding();
		hud.updateTime = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		if(achievementObj != null) {
			return;
		} else {
			var achieve:String = checkForAchievement(['week1_nomiss', 'week2_nomiss', 'week3_nomiss', 'week4_nomiss',
				'week5_nomiss', 'week6_nomiss', 'ur_bad',
				'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);

			if(achieve != null) {
				startAchievement(achieve);
				return;
			}
		}
		#end
		
		var ret:Dynamic = callOnScripts('onEndSong');
		var cause:String = 'gotoMenus';
		if (transitioning || ret == Globals.Function_Stop)
			return;

		transitioning = true;

		// Save song score and rating.
		if (saveScore && ratingFC != 'Fail')
			Highscore.saveScoreRecord(SONG.song, difficultyName, stats.getScoreRecord());

		var gotoNextThing:Void -> Void = gotoMenus;
		var nextSong:SongMetadata = null;
		var hi:Array<Dynamic> = ['gotoChartingEditor'];
		if (chartingMode) {
			gotoNextThing = null;
			openChartEditor();
			
		}
		else {
			nextSong = songPlaylist[++songPlaylistIdx];
		} 

		if (isStoryMode) {
			// TODO: add a modcharted variable which songs w/ modcharts should set to true, then make it so if modcharts are disabled the score wont get added
			// same check should be in the saveScore check above too
			if (ratingFC != 'Fail')
				campaignScore += stats.score;
			campaignMisses += songMisses;

			if (nextSong == null && saveScore && WeekData.curWeek != null) {
				// Week ended, save week score
				if (!practiceMode && !cpuControlled && !playOpponent) {
					Highscore.saveWeekScore(WeekData.curWeek.name, campaignScore);						
				}
			}
		}

		if (nextSong != null) {
			trace('LOADING NEXT SONG: $nextSong');

			prevCamFollow = camFollow;
			prevCamFollowPos = camFollowPos;
			cause = 'gotoNextSong';
			gotoNextThing = function gotoNextSong() {
				
				var callBack = function () {if (FlxG.state is PlayState) {
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
				}
				nextSong.play(difficultyName);
			}
			}
		}

		if (gotoNextThing != null) {
			hi = [cause, gotoNextThing];
		/*	#if VIDEOS_ALLOWED
			var videoPath:String = postSongVideo;
			if (videoPath.length > 0 && Paths.exists(videoPath = Paths.video(postSongVideo))) 
				MusicBeatState.switchState(new VideoPlayerState(videoPath, gotoNextThing));	
			else
			#end*/
			gotoNextThing();

		}
		
		
		callOnScripts('onSongEnd');
	}

	public function KillNotes() {
		while(allNotes.length > 0) {
			var daNote:Note = allNotes[0];
			daNote.active = false;
			daNote.visible = false;

			daNote.kill();
			notes.remove(daNote, true);
			// daNote.destroy();
		}
		allNotes = [];
		unspawnNotes = [];
		for(field in playfields){
			field.clearDeadNotes();
			field.spawnedNotes = [];
			field.noteQueue = [[], [], [], []];
		}

		eventNotes = [];
	}

	var lastJudge:RatingSprite;
	var lastCombos:Array<RatingSprite> = [];

	private function displayJudgment(image:String){
		var r:Bool = false;
		if(hudSkinScript!=null && callScript(hudSkinScript, "onDisplayJudgment", [image]) == Globals.Function_Stop)
			r = true;
		if(callOnScripts("onDisplayJudgment", [image]) == Globals.Function_Stop)
			return;

		if(r)return;

		var spr:RatingSprite;

		if (ClientPrefs.simpleJudge) {
			//// this legit just the ratinggroup code, fuckk!!!!
			spr = ratingGroup.addOnTop(lastJudge);
			spr.cancelTween();

			spr.active = true;
			spr.alive = true;
			spr.exists = true;

			spr.x = ratingGroup.x + ClientPrefs.comboOffset[0];
			spr.y = ratingGroup.y - ClientPrefs.comboOffset[1];

			spr.loadGraphic(Paths.image(image));
			spr.updateHitbox();

			////
			spr.moves = false;
			spr.scale.set(0.7 * 1.1, 0.7 * 1.1);
			spr.tween = FlxTween.tween(spr.scale, {x: 0.7, y: 0.7}, 0.1, {
				ease: FlxEase.quadOut,
				onComplete: function(tween:FlxTween) {
					if (!spr.alive)
						return;

					var stepDur = (Conductor.stepCrochet * 0.001);
					spr.tween = FlxTween.tween(spr.scale, {x: 0, y: 0}, stepDur, {
						startDelay: stepDur * 8,
						ease: FlxEase.quadIn,
						onComplete: (tween:FlxTween) -> spr.kill()
					});
				}
			});
		} else {
			spr = worldCombos ? ratingGroup.displayJudgment(image) : ratingGroup.displayJudgment(image, ClientPrefs.comboOffset[0], -ClientPrefs.comboOffset[1]);

			spr.moves = true;
			spr.acceleration.y = 550;
			spr.velocity.set(FlxG.random.int(-10, 10), -FlxG.random.int(140, 175));

			spr.scale.set(0.666, 0.666);
			spr.alpha = 1.0;

			spr.tween = FlxTween.tween(spr.scale, {x: 0.7, y: 0.7}, 0.1, {ease: FlxEase.backOut, onComplete: function(twn){
				spr.tween = FlxTween.tween(spr, {alpha: 0.0}, 0.2, {
						startDelay: Conductor.crochet * 0.001,
						onComplete: (_) -> spr.kill()
					});
			}});
		}

        spr.color = 0xFFFFFFFF;
		spr.visible = showRating;
		spr.alpha = ClientPrefs.judgeOpacity;	

        if(hudSkinScript!=null)
            callScript(hudSkinScript, "onDisplayJudgmentPost", [spr, image]);
        callOnScripts("onDisplayJudgmentPost", [spr, image]);
	}
	
	var comboColor = 0xFFFFFFFF;
	private function displayCombo(?combo:Int){
        var r:Bool = false;
        if (hudSkinScript!=null && callScript(hudSkinScript, "onDisplayCombo", [combo]) == Globals.Function_Stop)
            r = true;

        if (callOnScripts("onDisplayCombo", [combo]) == Globals.Function_Stop || r)
            return;

		if (combo == null) 
			combo = stats.combo;

		if (ClientPrefs.simpleJudge) {
			for (numSpr in lastCombos)
				numSpr.kill();
			
			if (combo == 0)
				return;
		}else{
			if (combo > 0 && combo < 10)
				return;
		}
		
		lastCombos = (worldCombos) ? ratingGroup.displayCombo(combo) : ratingGroup.displayCombo(combo, ClientPrefs.comboOffset[2], -ClientPrefs.comboOffset[3]);
		var comboColor = (combo < 0) ? hud.judgeColours.get("miss") : comboColor;
		
		for (numSpr in lastCombos)
		{
			numSpr.color = comboColor;
			numSpr.visible = showComboNum;

			numSpr.alpha = ClientPrefs.judgeOpacity;

			if (ClientPrefs.simpleJudge)
			{
				numSpr.moves = false;

				numSpr.scale.set(0.5, 0.5);
				numSpr.scale.x *= 1.25;
				numSpr.updateHitbox();
				numSpr.scale.y *= 0.75;

				numSpr.tween = FlxTween.tween(numSpr.scale, {x: 0.5, y: 0.5}, 0.2, {ease: FlxEase.circOut});
			}
			else
			{
				numSpr.moves = true;
				numSpr.acceleration.y = FlxG.random.int(200, 300);
				numSpr.velocity.set(FlxG.random.float(-5, 5), -FlxG.random.int(140, 160));

				numSpr.scale.set(0.5, 0.5);
				numSpr.updateHitbox();

				numSpr.tween = FlxTween.tween(numSpr, {alpha: 0.0}, 0.2, {
					startDelay: Conductor.crochet * 0.002,
					onComplete: (_) -> numSpr.kill()
				});
			}
		}

        if(hudSkinScript!=null)callScript(hudSkinScript, "onDisplayComboPost", [combo]);
        callOnScripts("onDisplayComboPost", [combo]);
	}

	private function applyJudgmentData(judgeData:JudgmentData, diff:Float, ?bot:Bool = false, ?show:Bool = true){
		if(judgeData==null){
			trace("you didnt give a valid JudgmentData to applyJudgmentData!");
			return;
		}
        if(callOnScripts("onApplyJudgmentData", [judgeData, diff, bot, show]) == Globals.Function_Stop)
            return;

		if (!bot)stats.score += Math.floor(judgeData.score * playbackRate);
		health += (judgeData.health * 0.02) * (judgeData.health < 0 ? healthLoss : healthGain);
		songHits++;


		if(ClientPrefs.wife3){
			if (judgeData.wifePoints == null)
				stats.totalNotesHit += Wife3.getAcc(diff);
			else
				stats.totalNotesHit += judgeData.wifePoints;
			stats.totalPlayed += 2;
		}else{
			stats.totalNotesHit += judgeData.accuracy * 0.01;
			stats.totalPlayed++;
		}

		switch(judgeData.comboBehaviour){
			default:
				stats.cbCombo = 0;
				stats.combo++;
			case BREAK:
				breakCombo();
			case IGNORE:
		}

		if (!stats.judgements.exists(judgeData.internalName))
			stats.judgements.set(judgeData.internalName, 0);

		stats.judgements.set(judgeData.internalName, stats.judgements.get(judgeData.internalName) + 1);
		
		RecalculateRating();

		if (ClientPrefs.coloredCombos)
		{
			if (stats.judgements.get("bad") > 0 || stats.judgements.get("shit") > 0 || stats.comboBreaks > 0)
				comboColor = 0xFFFFFFFF;
			else if (stats.judgements.get("good") > 0)
				comboColor = hud.judgeColours.get("good");
			else if (stats.judgements.get("sick") > 0)
				comboColor = hud.judgeColours.get("sick");
			else if (stats.judgements.get("epic") > 0)
				comboColor = hud.judgeColours.get("epic");
		}

        if(hudSkinScript!=null)callScript(hudSkinScript, "onApplyJudgmentDataPost", [judgeData, diff, bot, show]);
        callOnScripts("onApplyJudgmentDataPost", [judgeData, diff, bot, show]);

		if(show){
			if(judgeData.hideJudge!=true)
				displayJudgment(judgeData.internalName);
			if(judgeData.comboBehaviour != IGNORE)
				displayCombo(judgeData.comboBehaviour == BREAK ? (stats.cbCombo > 1 ? -stats.cbCombo : 0) : stats.combo);
		}
	}

	private function applyNoteJudgment(note:Note, bot:Bool = false):Null<JudgmentData>
	{
		if(note.hitResult.judgment == UNJUDGED)return null;
		var judgeData:JudgmentData = judgeManager.judgmentData.get(note.hitResult.judgment);
		if(judgeData==null)return null;

		if (callOnHScripts("onApplyNoteJudgment", [note, judgeData, bot]) == Globals.Function_Stop)
			return null;

		var mutatedJudgeData:JudgmentData = Reflect.copy(judgeData);
        if (note.noteScript != null){
			var ret:Dynamic = callScript(note.noteScript, "mutateJudgeData", [note, mutatedJudgeData]);
			if (ret != null && ret != Globals.Function_Continue)
				mutatedJudgeData = cast ret;
        }
        var ret:Dynamic = callOnHScripts("mutateJudgeData", [note, mutatedJudgeData]);
		if (ret != null && ret != Globals.Function_Continue)
			mutatedJudgeData = cast ret; // so you can return your own custom judgements or w/e

		applyJudgmentData(mutatedJudgeData, note.hitResult.hitDiff, bot, true);

		callOnHScripts("onApplyNoteJudgmentPost", [note, mutatedJudgeData, bot]);
		
		return mutatedJudgeData;
	}

	private function applyJudgment(judge:Judgment, ?diff:Float = 0, ?show:Bool = true)
		applyJudgmentData(judgeManager.judgmentData.get(judge), diff);

	//// for the not done yet, who knows if ever, results screen.
	var msJudges = [];
	var msNumber = 0;
	var msTotal = 0.0;

	private function judge(note:Note, field:PlayField=null){
		if (field == null)
			field = getFieldFromNote(note);

		var hitTime = note.hitResult.hitDiff + ClientPrefs.ratingOffset;
		var judgeData:JudgmentData = applyNoteJudgment(note, field.autoPlayed);
		if(judgeData==null)return;

		note.ratingMod = judgeData.accuracy * 0.01;
		note.rating = judgeData.internalName;
		if (note.noteSplashBehaviour == FORCED || judgeData.noteSplash && !note.noteSplashDisabled)
			spawnNoteSplashOnNote(note, field);
		
		msJudges.push({hitTime: hitTime, strumTime: note.strumTime});

		if(ClientPrefs.showMS && (field==null || !field.autoPlayed))
		{
			FlxTween.cancelTweensOf(timingTxt);
			FlxTween.cancelTweensOf(timingTxt.scale);
			
			timingTxt.text = '${FlxMath.roundDecimal(hitTime, 2)}ms';
			timingTxt.screenCenter();
			timingTxt.x += ClientPrefs.comboOffset[4];
			timingTxt.y -= ClientPrefs.comboOffset[5];

			timingTxt.color = hud.judgeColours.get(judgeData.internalName);

			timingTxt.visible = true;
			timingTxt.alpha = ClientPrefs.judgeOpacity;
			timingTxt.y -= 8;
			timingTxt.scale.set(1, 1);
			
			var time = (Conductor.stepCrochet * 0.001);
			FlxTween.tween(timingTxt, 
				{y: timingTxt.y + 8}, 
				0.1,
				{onComplete: function(_){
					if (ClientPrefs.simpleJudge){
						FlxTween.tween(timingTxt.scale, {x: 0, y: 0}, time, {
							ease: FlxEase.quadIn,
							onComplete: function(_){timingTxt.visible = false;},
							startDelay: time * 8
						});
					}else{
						FlxTween.tween(timingTxt, {alpha: 0}, time, {
							// ease: FlxEase.circOut,
							onComplete: function(_){timingTxt.visible = false;},
							startDelay: time * 8
						});
					}
				}}
			);
		}

		hud.noteJudged(judgeData, note, field);
	}

	public var strumsBlocked:Array<Bool> = [];
	var pressed:Array<FlxKey> = [];

	private function onKeyPress(event:KeyboardEvent):Void
	{
		if (paused || !startedCountdown || inCutscene)
			return;

		var eventKey:FlxKey = event.keyCode;
		var data:Int = getKeyFromEvent(eventKey);

		if (pressed.contains(eventKey))
            return;
        pressed.push(eventKey);

        if (callOnScripts("onKeyDown", [event]) == Globals.Function_Stop)
            return;

		if (data > -1){
			var hitNotes:Array<Note> = [];
            var controlledFields:Array<PlayField> = [];

			if(strumsBlocked[data]) return;
            
			if (callOnScripts("onKeyPress", [data]) == Globals.Function_Stop)
				return;
        
			for(field in playfields.members){
				if(!field.autoPlayed && field.isPlayer && field.inControl){
                    controlledFields.push(field);
					field.keysPressed[data] = true;
					if(generatedMusic && !endingSong){
                        var note:Note = null;
                        var ret:Dynamic = callOnHScripts("onFieldInput", [field, data, hitNotes]);
						if (ret == Globals.Function_Stop)
							continue;
                        else if((ret is Note))
                            note = ret;
                        else
						    note = field.input(data);

						if(note==null){
							var spr:StrumNote = field.strumNotes[data];
							if (spr != null && spr.animation.curAnim.name != 'confirm')
							{
								spr.playAnim('pressed');
								spr.resetAnim = 0;
							}
						}else
							hitNotes.push(note);
                        

					}
				}
			}
			if (hitNotes.length==0 && controlledFields.length > 0){
				callOnScripts('onGhostTap', [data]);
				
				if (!ClientPrefs.ghostTapping)
					noteMissPress(data);
			}
		}
	}
	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		if(pressed.contains(eventKey))pressed.remove(eventKey);
        
        if (callOnScripts("onKeyUp", [event]) == Globals.Function_Stop)
            return;

		if(startedCountdown && key > -1)
		{
			// doesnt matter if THIS is done while paused
			// only worry would be if we implemented Lifts
			// but afaik we arent doing that
			// (though could be interesting to add)
			for(field in playfields.members){
				if (field.inControl && !field.autoPlayed && field.isPlayer)
				{
					field.keysPressed[key] = false;
					
					if(!field.isHolding[key]){
						var spr:StrumNote = field.strumNotes[key];
						if (spr != null){
							spr.playAnim('static');
							spr.resetAnim = 0;
						}
					}
				}
			}
			callOnScripts('onKeyRelease', [key]);
		}
		//trace('released: ' + controlArray);
	}

	private function getKeyFromEvent(key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...keysArray.length)
			{
				for (j in 0...keysArray[i].length)
				{
					if(key == keysArray[i][j])
					{
						return i;
					}
				}
			}
		}
		return -1;
	}

	// Hold notes
	public static var pressedGameplayKeys:Array<Bool> = [];

	private function keyShit():Void
	{
		if (inCutscene) return;


		// HOLDING
		var parsedHoldArray:Array<Bool> = parseKeys();
		pressedGameplayKeys = parsedHoldArray;

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if (ClientPrefs.controllerMode)
		{
			var parsedArray:Array<Bool> = parseKeys('_P');
			if (parsedArray.contains(true))
			{
				for (i in 0...parsedArray.length)
				{
					if (parsedArray[i] && strumsBlocked[i] != true)
						onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[i][0]));
				}
			}
		}

		/*
		if (startedCountdown && !boyfriend.stunned && generatedMusic)
		{
			if (parsedHoldArray.contains(true) && !endingSong) {
				#if ACHIEVEMENTS_ALLOWED
				var achieve:String = checkForAchievement(['oversinging']);
				if (achieve != null) {
					startAchievement(achieve);
				}
				#end
			}
		}
		*/

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if (ClientPrefs.controllerMode || strumsBlocked.contains(true))
		{
			var parsedArray:Array<Bool> = parseKeys('_R');
			if (parsedArray.contains(true))
			{
				for (i in 0...parsedArray.length)
				{
					if (parsedArray[i] || strumsBlocked[i] == true)
						onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[i][0]));
				}
			}
		}
	}

	private function parseKeys(?suffix:String = ''):Array<Bool>
	{
		var ret:Array<Bool> = [];
		for (i in 0...controlArray.length)
			ret[i] = Reflect.getProperty(controls, controlArray[i] + suffix);
		return ret;
	}

	function breakCombo(){
		stats.comboBreaks++;
		stats.cbCombo++;
		stats.combo = 0;
		while (lastCombos.length > 0)
			lastCombos.shift().kill();
		RecalculateRating();
	}

	// You didn't hit the key and let it go offscreen, also used by Hurt Notes
	function noteMiss(daNote:Note, field:PlayField, ?mine:Bool=false):Void 
	{
		//Dupe note remove
		//field.spawnedNotes.forEachAlive(function(note:Note) {
		for(note in field.spawnedNotes){
			if(!note.alive || daNote.tail.contains(note) || note.isSustainNote) 
				continue;

			if (daNote != note && field.isPlayer && daNote.column == note.column && Math.abs(daNote.strumTime - note.strumTime) < 1) 
				field.removeNote(note);
		}

		if (daNote.sustainLength > 0 && ClientPrefs.wife3)
			daNote.hitResult.judgment = DROPPED_HOLD;
		else
			daNote.hitResult.judgment = MISS;

		if(callOnHScripts("preNoteMiss", [daNote, field]) == Globals.Function_Stop)
			return;
		if (daNote.noteScript != null && callScript(daNote.noteScript, "preNoteMiss", [daNote, field]) == Globals.Function_Stop)
			return;

		////
		if(!daNote.isSustainNote && daNote.unhitTail.length > 0){
			for(tail in daNote.unhitTail){
				tail.tooLate = true;
				tail.blockHit = true;
				tail.ignoreNote = true;
				//health -= daNote.missHealth * healthLoss; // this is kinda dumb tbh no other VSRG does this just FNF
			}
		}

		if (ClientPrefs.ghostTapping && !daNote.noMissAnimation)
		{
			var chars:Array<Character> = daNote.characters;

			if (daNote.gfNote && gf != null)
				chars.push(gf);
			else if (chars.length == 0)
				chars = field.characters;

			if (stats.combo > 10 && gf!=null && chars.contains(gf) == false && gf.animOffsets.exists('sad'))
			{
				gf.playAnim('sad');
				gf.specialAnim = true;
			}

			for(char in chars){
				if(char != null && char.animTimer <= 0 && !char.voicelining)
				{
					var daAlt = (daNote.noteType == 'Alt Animation') ? '-alt' : '';
					var animToPlay:String = singAnimations[Std.int(Math.abs(daNote.column))] + daAlt + 'miss';

					char.playAnim(animToPlay, true);

					if (!char.hasMissAnimations)
						char.colorOverlay = char.missOverlayColor;	
				}	
			}
		}

		
		if (!mine){
			songMisses++;
			applyJudgment(daNote.hitResult.judgment);
		}else{
			applyJudgment(MISS_MINE);
			health -= daNote.missHealth * healthLoss;
		}
		
		for (track in (playOpponent ? opponentTracks : playerTracks))
			track.volume = 0;

		if (ClientPrefs.ghostTapping && !daNote.isSustainNote && ClientPrefs.missVolume > 0)
			FlxG.sound.play(Paths.soundRandom('missnote'+missSuffix, 1, 3), ClientPrefs.missVolume * FlxG.random.float(0.9, 1) );

		if(instakillOnMiss)
			doDeathCheck(true);

		////
		callOnHScripts("noteMiss", [daNote, field]);
		#if LUA_ALLOWED
		callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.column, daNote.noteType, daNote.isSustainNote, daNote.ID]);
		#end
		if (daNote.noteScript != null)
			callScript(daNote.noteScript, "noteMiss", [daNote, field]);
		if (daNote.genScript != null)
			callScript(daNote.genScript, "noteMiss", [daNote, field]); 
	}

	function noteMissPress(direction:Int = 1):Void //You pressed a key when there was no notes to press for this key
	{
		health -= 0.05 * healthLoss;
		if (vocals != null)
		vocals.volume = 0;

		if(instakillOnMiss)
			doDeathCheck(true);

		if (stats.combo > 10 && gf != null && gf.animOffsets.exists('sad')){
			gf.playAnim('sad');
			gf.specialAnim = true;
		}
		
		if(!practiceMode) stats.score -= 10;
		if(!endingSong) songMisses++;

		breakCombo();
		
		// i dont think this should reduce acc lol
		//totalPlayed++;
		//RecalculateRating();

		if (ClientPrefs.missVolume > 0)
			FlxG.sound.play(Paths.soundRandom('missnote'+missSuffix, 1, 3), ClientPrefs.missVolume  * FlxG.random.float(0.9, 1));

		for (field in playfields.members)
		{
			if (!field.isPlayer)
				continue;

			for(char in field.characters)
			{
				if(char.animTimer <= 0 && !char.voicelining)
				{
					char.playAnim(singAnimations[Std.int(Math.abs(direction))] + 'miss', true);
					if(!char.hasMissAnimations)
						char.colorOverlay = char.missOverlayColor;	
				}
			}
		}

		callOnScripts('noteMissPress', [direction]);
	}

	function opponentNoteHit(note:Note, field:PlayField):Void
	{
		if (note.noteScript != null && callScript(note.noteScript, "preNoteHit", [note, field]) == Globals.Function_Stop)
			return;
		if (callOnHScripts("preNoteHit", [note, field]) == Globals.Function_Stop)
			return;
		if (note.noteScript != null && callScript(note.noteScript, "preOpponentNoteHit", [note, field]) == Globals.Function_Stop)
			return;
		if (callOnHScripts("preOpponentNoteHit", [note, field]) == Globals.Function_Stop)
			return;

		camZooming = true;

		var chars:Array<Character> = note.characters;
		if (note.gfNote && gf != null)
			chars.push(gf);
		if (chars.length == 0)
			chars = field.characters;

		for(char in chars){
			if (!char.canSing || char.callOnScripts("playNote", [note, field]) == Globals.Function_Stop)
			{
				// nada
			}	
			else if(note.noteType == 'Hey!' && char.animOffsets.exists('hey')) 
			{
				char.playAnim('hey', true);
				char.specialAnim = true;
				char.heyTimer = 0.6;
			} 
			else if(!note.noAnimation) 
			{
				var animToPlay:String = singAnimations[Std.int(Math.abs(note.column))];

				var curSection = SONG.notes[curSection];
				if ((curSection != null && curSection.altAnim) || note.noteType == 'Alt Animation')
					animToPlay += '-alt';

				if (char.animTimer <= 0 && !char.voicelining){
					char.playAnim(animToPlay, true);
					char.holdTimer = 0;
					char.callOnScripts("playNoteAnim", [animToPlay, note]);
				}
			}
		}

		note.hitByOpponent = true;
		for (track in opponentTracks)
			track.volume = 1.0;

		var time:Float = 0.15;
		if (note.isSustainNote)
			time += 0.15;
		// Strum animations
		if (note.visible){
			StrumPlayAnim(field, Std.int(Math.abs(note.column)) % keyCount, time, note);
			if (ClientPrefs.noteHoldSplashes && field != null) {
			var spr = field.grpNoteHoldSplashes.members[note.column];
			switch (note.holdType){
				case TAP: 
				case HEAD:	spr.animation.play('start');
							spr.visible = true;
				case PART:	
				case END:	//spr.playHoldEnd = true;
			}
			var skin:String = '';
			var hue:Float;
			var sat:Float;
			var brt:Float;
	
			if (note != null) {
				skin = note.texPrefix;
				hue = note.noteSplashHue;
				sat = note.noteSplashSat;
				brt = note.noteSplashBrt;
			}else{
				hue = sat = brt = 0.0;
				
				/*var hsb = ClientPrefs.arrowHSV[note.column % 4]; 
				hue = hsb[0] / 360;
				sat = hsb[1] / 100;
				brt = hsb[2] / 100;*/
			}

			spr.setHoldPos(0,0,note.column,hue,sat,brt);
			spr.resetAnim = time;
		}
		}

		// Script shit
		callOnHScripts("opponentNoteHit", [note, field]);
		callOnHScripts("onNoteHit", [note, field]);
		if (note.noteScript != null){
			callScript(note.noteScript, "opponentNoteHit", [note, field]);
			callScript(note.noteScript, "onNoteHit", [note, field]);
		}
		if (note.genScript != null){
			callScript(note.genScript, "noteHit", [note, field]);
		}
		
		#if LUA_ALLOWED
		callOnLuas('opponentNoteHit', [notes.members.indexOf(note), Math.abs(note.column), note.noteType, note.isSustainNote, note.ID]);
		callOnLuas('onNoteHit', [notes.members.indexOf(note), Math.abs(note.column), note.noteType, note.isSustainNote, note.ID]);
		#end

		if (!note.isSustainNote)
		{
			if (opponentHPDrain > 0 && health > opponentHPDrain)
				health -= opponentHPDrain;

			if(note.sustainLength == 0)
				field.removeNote(note);
		}
		else if (note.isSustainNote)
			if (note.parent.unhitTail.contains(note))
				note.parent.unhitTail.remove(note);
		
	}

	function defaultNoteHit(note:Note, field:PlayField):Void
		{
			if (note.noteScript != null && callScript(note.noteScript, "preNoteHit", [note, field]) == Globals.Function_Stop)
				return;
			if (callOnHScripts("preNoteHit", [note, field]) == Globals.Function_Stop)
				return;
			if (note.noteScript != null && callScript(note.noteScript, "preDefaultNoteHit", [note, field]) == Globals.Function_Stop)
				return;
			if (callOnHScripts("preDefaultNoteHit", [note, field]) == Globals.Function_Stop)
				return;
	
			camZooming = true;
			// Strum animations
			if (note.visible){
				var time:Float = 0.15;
				if (note.isSustainNote)
					time += 0.15;
	
				StrumPlayAnim(field, Std.int(Math.abs(note.column)) % keyCount, time, note);
			}
	
			// Script shit
			callOnHScripts("defaultNoteHit", [note, field]);
			callOnHScripts("onNoteHit", [note, field]);
			if (note.noteScript != null){
				callScript(note.noteScript, "defaultNoteHit", [note, field]);	
				callScript(note.noteScript, "onNoteHit", [note, field]);	
			}
			if (note.genScript != null)
				callScript(note.genScript, "noteHit", [note, field]);
			
			#if LUA_ALLOWED
			callOnLuas('defaultNoteHit', [notes.members.indexOf(note), Math.abs(note.column), note.noteType, note.isSustainNote, note.ID]);
			#end
	
			if (!note.isSustainNote)
			{
				if (opponentHPDrain > 0 && health > opponentHPDrain)
					health -= opponentHPDrain;
	
				if(note.sustainLength == 0)
					field.removeNote(note);
			}
			else if (note.isSustainNote)
				if (note.parent.unhitTail.contains(note))
					note.parent.unhitTail.remove(note);
			
		}

    // diff from goodNoteHit because it gets called when you release and re-press a hold
    // prob be useful for noteskins too

    inline function stepHold(note:Note, field:PlayField)
	{
		callOnHScripts("onHoldPress", [note, field]);
		
		if (note.noteScript != null)
			callScript(note.noteScript, "onHoldPress", [note, field]);

		if (note.genScript != null)
			callScript(note.genScript, "onHoldPress", [note, field]);
	}
	
	inline function dropHold(note:Note, field:PlayField): Void
	{
		callOnHScripts("onHoldRelease", [note, field]);
		
		if (note.noteScript != null)
			callScript(note.noteScript, "onHoldRelease", [note, field]);

		if (note.genScript != null)
			callScript(note.genScript, "onHoldRelease", [note, field]);
		
	}

	function goodNoteHit(note:Note, field:PlayField):Void
	{	
		if (note.wasGoodHit || (field.autoPlayed && (note.ignoreNote || note.breaksCombo)))
			return;

		if (note.noteScript != null && callScript(note.noteScript, "preNoteHit", [note, field]) == Globals.Function_Stop)
			return;
		if (callOnHScripts("preNoteHit", [note, field]) == Globals.Function_Stop)
			return;

		if (note.noteScript != null && callScript(note.noteScript, "preGoodNoteHit", [note, field]) == Globals.Function_Stop)
			return;
		if (callOnHScripts("preGoodNoteHit", [note, field]) == Globals.Function_Stop)
			return;

		camZooming = true;

		if(!note.isSustainNote){
			noteHits.push(Conductor.songPosition); // used for NPS
			stats.noteDiffs.push(note.hitResult.hitDiff + ClientPrefs.ratingOffset); // used for stat saving (i.e viewing song stats after you beaten it)
        }

		if (!note.hitsoundDisabled && ClientPrefs.hitsoundVolume > 0)
			FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.hitsoundVolume );

		// tbh I hate hitCausesMiss lol its retarded
		// added a shitty judge to deal w/ it tho!! 
 		if (note.hitResult.judgment == MISS_MINE) 
		{
			noteMiss(note, field, true);

			if (!note.noMissAnimation)
			{
				switch (note.noteType)
				{
					case 'Hurt Note': // Hurt note
						var chars:Array<Character> = note.characters;
						if (note.gfNote)
							chars.push(gf);
						else if (chars.length == 0)
							chars = field.characters;

						for(char in chars){
							if (char.animation.getByName('hurt') != null){
								char.playAnim('hurt', true);
								char.specialAnim = true;
							}
						}

				}
			}

			note.wasGoodHit = true;
			if (!note.isSustainNote && note.sustainLength==0)
				field.removeNote(note);
			else if(note.isSustainNote){
				if (note.parent != null)
					if (note.parent.unhitTail.contains(note))
						note.parent.unhitTail.remove(note);
			}

			return;
		} 

		if (!note.isSustainNote)
			judge(note, field);

		// Sing animations
		var chars:Array<Character> = note.characters;
		if (note.gfNote){
			for (char in gfGroup.members){
				if ((char is Character)){
				var girlfriend:Character = cast char;
				chars.push(girlfriend);
				}
			}
			
		}
		if (chars.length == 0)
			chars = field.characters;
		
		for (char in chars)
		{
			if (!char.canSing || char.callOnScripts("playNote", [note, field]) == Globals.Function_Stop)
			{
				// nada
			}	
			else if(note.noteType == 'Hey!') 
			{
				char.playAnim('hey', true);
				char.specialAnim = true;
				char.heyTimer = 0.6;

				if (gf != null && gf.animOffsets.exists('cheer')) 
				{
					gf.playAnim('cheer', true);
					gf.specialAnim = true;
					gf.heyTimer = 0.6;
				}
			} 
			else if(!note.noAnimation) 
			{
				var animToPlay:String = singAnimations[Std.int(Math.abs(note.column))];

				var curSection = SONG.notes[curSection];
				if ((curSection != null && curSection.altAnim) || note.noteType == 'Alt Animation')
					animToPlay += '-alt';

				if (char.animTimer <= 0 && !char.voicelining){
					char.playAnim(animToPlay, true);
					char.holdTimer = 0;
					char.callOnScripts("playNoteAnim", [animToPlay, note]);
				}
			}
		}

		note.wasGoodHit = true;
		if (cpuControlled) saveScore = false; // if botplay hits a note, then you lose scoring
		for (track in playerTracks)
			track.volume = 1.0;

		var time:Float = 0.15;
		if (note.isSustainNote)
			time += 0.15;

		// Strum animations
		if (note.visible){
			if(field.autoPlayed){
				StrumPlayAnim(field, Std.int(Math.abs(note.column)) % keyCount, time, note);
			}else{
				var spr = field.strumNotes[note.column];
				if (spr != null && (field.keysPressed[note.column] || note.isRoll))
					spr.playAnim('confirm', true, note.isSustainNote ? note.parent : note);
			}
			if (ClientPrefs.noteHoldSplashes && note != null && field != null) {
				var spr = field.grpNoteHoldSplashes.members[note.column];
			switch (note.holdType){
				case TAP: 
				case HEAD:	spr.animation.play('start');
							spr.visible = true;
				case PART:	
				case END:	spr.playHoldEnd = true;
			}
			var skin:String = '';
			var hue:Float;
			var sat:Float;
			var brt:Float;
	
			if (note != null) {
				skin = note.texPrefix;
				hue = note.noteSplashHue;
				sat = note.noteSplashSat;
				brt = note.noteSplashBrt;
			}else{
				hue = sat = brt = 0.0;
				
				/*var hsb = ClientPrefs.arrowHSV[note.column % 4]; 
				hue = hsb[0] / 360;
				sat = hsb[1] / 100;
				brt = hsb[2] / 100;*/
			}

			spr.setHoldPos(0,0,note.column,hue,sat,brt);
			spr.resetAnim = time;
		}
		}

		// Script shit
		callOnHScripts("goodNoteHit", [note, field]);
		callOnHScripts("onNoteHit", [note, field]);
		if (note.noteScript != null){
			callScript(note.noteScript, "goodNoteHit", [note, field]);
			callScript(note.noteScript, "onNoteHit", [note, field]);
		}
		if (note.genScript != null)
			callScript(note.genScript, "noteHit", [note, field]); // might be useful for some things i.e judge explosions

		#if LUA_ALLOWED
		callOnLuas('goodNoteHit', [notes.members.indexOf(note), Math.round(Math.abs(note.column)), note.noteType, note.isSustainNote, note.ID]);
		callOnLuas('onNoteHit', [notes.members.indexOf(note), Math.round(Math.abs(note.column)), note.noteType, note.isSustainNote, note.ID]);
		#end
		
		if (!note.isSustainNote && note.sustainLength == 0)
			field.removeNote(note);
		else if (note.isSustainNote)
		{
			if (note.parent != null)
				if (note.parent.unhitTail.contains(note))
					note.parent.unhitTail.remove(note);
		}
	}

	function getFieldFromNote(note:Note){

		for (playfield in playfields)
		{
			if (playfield.hasNote(note))
				return playfield;
		}

		return playfields.members[0];
	}

	public function spawnNoteSplashOnNote(note:Note, ?field:PlayField) {
		if (ClientPrefs.noteSplashes && note != null) {
			if(field==null)
				field = getFieldFromNote(note);

			var strum:StrumNote = field.strumNotes[note.column];
			if(strum != null) {
				field.spawnSplash(note, splashSkin);
			}
		}
	}

	public function cancelMusicFadeTween() {
/* 		if(inst.fadeTween != null) {
			inst.fadeTween.cancel();
		}
		inst.fadeTween = null; */
	}

	#if LUA_ALLOWED
	private var preventLuaRemove:Bool = false;

	public function createLua(path:String, ?scriptName:String, ?ignoreCreateCall:Bool):FunkinLua
	{
        var split = path.split("/");
        var modName:String = split[0] == "content" ? split[1] : 'assets';
        
		var script = FunkinLua.fromFile(path, scriptName, ignoreCreateCall, [
            "modName" => modName
        ]);

		luaArray.push(script);
		funkyScripts.push(script);
		return script;
	}

	public function removeLua(luaScript:FunkinLua):Void
	{
		if (!preventLuaRemove) {
			funkyScripts.remove(luaScript);
			luaArray.remove(luaScript);
		}
	}
	#end

	#if HSCRIPT_ALLOWED
	public function createHScript(path:String, ?scriptName:String, ?ignoreCreateCall:Bool):FunkinHScript
	{
        var split = path.split("/");
        var modName:String = split[0] == "content" ? split[1] : 'assets';
		var vars = ["modName" => modName];
		initPlayStateVars(vars);
		var script = FunkinHScript.fromFile(path, scriptName, vars, ignoreCreateCall != true);
		if (ignoreCreateCall != true){
			script.call('start',[SONG]);//M+ real
		}

		hscriptArray.push(script);
		funkyScripts.push(script);
		return script;
	}
	function initPlayStateVars(?script:Null<Map<String, Any>>,isStage:Bool = false){
		if (script != null){
			script.set('currentPlayState',instance);
			script.set('SONG',SONG);
			script.set('camGame',camGame);
			script.set('camStageUnderlay',camStageUnderlay);
			script.set('camHUD',camHUD);
			script.set('camHUD2',camOther);
			script.set('camOther',camOther);
			script.set('camOverlay',camOverlay);
			script.set('dadMap',dadMap);
			script.set('boyfriendMap',boyfriendMap);
			script.set('gfMap',gfMap);
			script.set('dad',dad);
			script.set('boyfriend',boyfriend);
			if(gf != null)
			script.set('gf',gf);
			if (!isStage){
			script.set('add',add);
			script.set('remove',remove);
			script.set('insert',insert);
			script.set('refresh',refresh);
			}
			script.set('extraMap',extraMap);
			script.set('precacheList',shitToLoad);
		}
	}
	public function removeHScript(script:FunkinHScript){
		funkyScripts.remove(script);
		hscriptArray.remove(script);
	}
	#end

	var lastStepHit:Int = -9999;
	override function stepHit()
	{
		super.stepHit();
		if (curStep < lastStepHit) 
			return;
		
		hud.stepHit(curStep);
		lastStepHit = curStep;
		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
		callOnScripts('stepHit',[curStep]);
	}

	public function cameraBump(camZoom:Float = 0.015, hudZoom:Float = 0.03)
	{
		if(FlxG.camera.zoom < (defaultCamZoom * 1.35))
			FlxG.camera.zoom += camZoom * camZoomingMult * ClientPrefs.camZoomP;
		camHUD.zoom += hudZoom * camZoomingMult * ClientPrefs.camZoomP;
	}

	public var zoomEveryBeat:Int = 4;
	public var beatToZoom:Int = 0;
		
	var lastBeatHit:Int;
	override function beatHit()
	{
		super.beatHit();
		if (curBeat < lastBeatHit) 
			return;
		
		hud.beatHit(curBeat);

		if (camZooming && ClientPrefs.camZoomP>0 && zoomEveryBeat > 0 && curBeat % zoomEveryBeat == beatToZoom)
		{
			cameraBump();
		}

		lastBeatHit = curBeat;

		setOnScripts('curBeat', curBeat);
		callOnScripts('onBeatHit');
		callOnScripts('beatHit',[curBeat]);
	}

	var lastSection:Int = -1;
	override function sectionHit(){
		var sectionNumber = curSection;
		var curSection = SONG.notes[sectionNumber];

		if (curSection == null)
			return;

		if (curSection.changeBPM)
		{
			Conductor.changeBPM(curSection.bpm);
			
			setOnScripts('curBpm', Conductor.bpm);
			setOnScripts('crochet', Conductor.crochet);
			setOnScripts('stepCrochet', Conductor.stepCrochet);
		}
		
		#if LUA_ALLOWED
		setOnLuas("curSection", sectionNumber);
		#end
		setOnHScripts("curSection", curSection);
		setOnScripts('sectionNumber', sectionNumber);

		setOnScripts('mustHitSection', curSection.mustHitSection == true);
		setOnScripts('altAnim', curSection.altAnim == true);
		setOnScripts('gfSection', curSection.gfSection  == true);

		if (lastSection != sectionNumber)
		{
			lastSection = sectionNumber;
			callOnScripts("onSectionHit");
			callOnScripts('sectionHit',[sectionNumber]);
		}

		if (generatedMusic && !endingSong)
		{
			moveCameraSection(curSection);
		}
	}

	inline public function callOnAllScripts(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>,
			?vars:Map<String, Dynamic>):Dynamic
			return callOnScripts(event, args, ignoreStops, exclusions, scriptArray, vars, false);

	inline public function isSpecialScript(script:FunkinScript)
		return notetypeScripts.exists(script.scriptName) || eventScripts.exists(script.scriptName) || hudSkinScripts.exists(script.scriptName);

	public function callOnScripts(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>,
			?vars:Map<String, Dynamic>, ?ignoreSpecialShit:Bool = true):Dynamic
	{
        #if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		while (scriptsToClose.length > 0){
			var script = scriptsToClose.pop();

			if (script is FunkinLua)
				luaArray.remove(cast script);
			else if (script is FunkinHScript)
				hscriptArray.remove(cast script);

			funkyScripts.remove(script);
			script.stop();
		}

		if (args == null) args = [];
		if (scriptArray == null) scriptArray = funkyScripts;
		if (exclusions == null) exclusions = [];
		
		var returnVal:Dynamic = Globals.Function_Continue;
		for (idx in 0...scriptArray.length)
		{
			var script:FunkinScript = scriptArray[idx];
			if (script==null || exclusions.contains(script.scriptName) || (ignoreSpecialShit && isSpecialScript(script)))			
				continue;
			
			var ret:Dynamic = script.call(event, args, vars);
			if (ret == Globals.Function_Halt){
				ret = returnVal;
				if (!ignoreStops)
					return returnVal;
			};
			if (ret != Globals.Function_Continue && ret!=null)
				returnVal = ret;
		}
		
		return (returnVal == null) ? Globals.Function_Continue : returnVal;
        #else
        return Globals.Function_Continue;
        #end
	}

	public function setOnScripts(variable:String, value:Dynamic, ?scriptArray:Array<Dynamic>)
	{
		if (scriptArray == null)
			scriptArray = funkyScripts;

		for (idx in 0...scriptArray.length){
            var script = scriptArray[idx];
			script.set(variable, value);
		}
	}

	public function callScript(script:Dynamic, event:String, ?args:Array<Dynamic>):Dynamic
	{
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED) // no point in calling this code if you.. for whatever reason, disabled scripting.
		if((script is FunkinScript)){
			return callOnScripts(event, args, true, [], [script], [], false);
		}
		else if((script is Array)){
			return callOnScripts(event, args, true, [], script, [], false);
		}
		else if((script is String)){
			var scripts:Array<FunkinScript> = [];

			for (idx in 0...funkyScripts.length)
			{
                var scr = funkyScripts[idx];
				if(scr.scriptName == script)
					scripts.push(scr);
			}

			return callOnScripts(event, args, true, [], scripts, [], false);
		}
        #end
		return Globals.Function_Continue;
	}

	#if HSCRIPT_ALLOWED
	public function callOnHScripts(event:String, ?args:Array<Dynamic>, ?vars:Map<String, Dynamic>, ignoreStops = false, ?exclusions:Array<String>):Dynamic
		return callOnScripts(event, args, ignoreStops, exclusions, hscriptArray, vars);
	
	public function setOnHScripts(variable:String, arg:Dynamic)
		return setOnScripts(variable, arg, hscriptArray);

	public function setDefaultHScripts(variable:String, arg:Dynamic){
		FunkinHScript.defaultVars.set(variable, arg);
		return setOnScripts(variable, arg, hscriptArray);
	}
    #else
	inline public function callOnHScripts(event:String, ?args:Array<Dynamic>, ?vars:Map<String, Dynamic>, ignoreStops = false, ?exclusions:Array<String>):Dynamic
		return Globals.Function_Continue;
	#end

	#if LUA_ALLOWED
	public function callOnLuas(event:String, ?args:Array<Dynamic>, ignoreStops = false, ?exclusions:Array<String>):Dynamic
		return callOnScripts(event, args, ignoreStops, exclusions, luaArray);
	
	public function setOnLuas(variable:String, arg:Dynamic)
		setOnScripts(variable, arg, luaArray);
    #else
	inline public function callOnLuas(event:String, ?args:Array<Dynamic>, ignoreStops = false, ?exclusions:Array<String>):Dynamic
		return Globals.Function_Continue;
	#end

	function StrumPlayAnim(field:PlayField, id:Int, time:Float, ?note:Note) {
		var spr:StrumNote = field.strumNotes[id];

		if (spr != null) {
			spr.playAnim('confirm', true, note);
			spr.resetAnim = time;
		}
	}

	public function RecalculateRating() {
		setOnScripts('score', stats.score);
		setOnScripts('misses', songMisses);
		setOnScripts('comboBreaks', stats.comboBreaks);
		setOnScripts('hits', songHits);

		callOnScripts('onRecalculateRating');

		stats.updateVariables();
		
		hud.recalculateRating();

		callOnScripts('postRecalculateRating'); // deprecated
        
        callOnScripts('onRecalculateRatingPost');

		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
	}

	////
	public function openPauseMenu()
	{
		if (callOnScripts('onPause') == Globals.Function_Stop) 
			return;
		
		// 0 chance for Gitaroo Man easter egg
		pause();
		persistentUpdate = false;
		persistentDraw = true;
		
		openSubState(new PauseSubState());
	}

	public function pause(){
		paused = true;
		if (rhythmMode){
			if (backGroundVideo != null){
				backGroundVideo.pause();
			}
		}
		if (inst != null)
		{
			for (track in tracks)
				track.pause();
		}

		if (curCountdown != null && !curCountdown.finished)
			curCountdown.timer.active = false;
		if (finishTimer != null && !finishTimer.finished)
			finishTimer.active = false;
		if (songSpeedTween != null)
			songSpeedTween.active = false;


		var chars:Array<Character> = [boyfriend, gf, dad];
		for (char in chars) {
			if(char != null && char.colorTween != null) {
				char.colorTween.active = false;
			}
		}

		for (tween in modchartTweens) {
			if (tween != null)
			tween.active = false;
		}
		for (timer in modchartTimers) {
			if (timer != null)
			timer.active = false;
		}

		#if DISCORD_ALLOWED
		DiscordClient.changePresence(detailsPausedText, stateText, songName);
		#end
	}

	public function resume(){
		if (!paused)
			return;
		if (rhythmMode){
			if (backGroundVideo != null){
				backGroundVideo.resume();
			}
		}
		paused = false;
		active = true;

		if (inst != null && !startingSong)
			resyncVocals();

		if (curCountdown != null && !curCountdown.finished)
			curCountdown.timer.active = true;
		if (finishTimer != null && !finishTimer.finished)
			finishTimer.active = true;
		if (songSpeedTween != null)
			songSpeedTween.active = true;

		var chars:Array<Character> = [boyfriend, gf, dad];
		for (char in chars) {
			if(char != null && char.colorTween != null) {
				char.colorTween.active = true;
			}
		}

		for (tween in modchartTweens) {
			if (tween != null)
			tween.active = true;
		}
		for (timer in modchartTimers) {
			if (timer != null)
			timer.active = true;
		}

		updateSongDiscordPresence();
	} 

	override public function startOutro(onOutroComplete)
	{
		callOnScripts("switchingState");

		return super.startOutro(onOutroComplete);
	}

	override function destroy() 
	{
		// Could probably do a results screen like the one on kade engine but for freeplay only. I think that could be cool.
		// ^ I was JUST thinking this. We can show the average NPS, accuracy, grade, judge counters, etc
		// I think just in general adding more stats could be neat & since we have the new options menu we can just put it in UI in a seperate category
		// so you can set exactly which stats show up in the scoretxt, etc

		/*
		trace(msJudges.length / {
			var total = 0.0;
			for (n in msJudges) total+=n;
			total;
		});
		*/
		FlxG.timeScale = 1;

		pressedGameplayKeys = null;

		if (!ClientPrefs.controllerMode) {
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		FunkinHScript.defaultVars.clear();
        
		FlxG.timeScale = 1.0;
		ClientPrefs.gameplaySettings.set('botplay', cpuControlled);
		if (backGroundVideo != null){
			backGroundVideo.destroy();
		}
        #if LUA_ALLOWED
		preventLuaRemove = true;
        #end

		if (funkyScripts != null) while (funkyScripts.length > 0){
			var script = funkyScripts.pop();
			script.call("onDestroy");
			script.stop();
		}
		
		if (hscriptArray != null) while (hscriptArray.length > 0)
			hscriptArray.pop();

		#if LUA_ALLOWED
		if (luaArray != null) while (luaArray.length > 0)
			luaArray.pop();

		if (FunkinLua.haxeScript != null)
			FunkinLua.haxeScript.stop();
		FunkinLua.haxeScript = null;
		#end

		sectionCamera.put();
		customCamera.put();
		
		if (cameraPoints != null) while (cameraPoints.length > 0)
			cameraPoints.pop().put();

		stats.changedEvent.removeAll();

		Note.quantShitCache.clear();
		FunkinHScript.defaultVars.clear();

		notetypeScripts.clear();
		hudSkinScripts.clear();		
		eventScripts.clear();

		//instance = null;

		super.destroy();
	}	
}
