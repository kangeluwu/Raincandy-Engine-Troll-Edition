package funkin.data;

import haxe.Timer;
#if(moonchart)
import funkin.data.FNFTroll as SupportedFormat;
import moonchart.formats.BasicFormat;
import moonchart.backend.FormatData;
import moonchart.backend.FormatData.Format;
import moonchart.backend.FormatDetector;
#end
import flixel.util.FlxSort;
import funkin.states.LoadingState;
import funkin.states.PlayState;
import funkin.data.Section.SwagSection;
import haxe.io.Path;
import haxe.Json;

using StringTools;

typedef SwagSong =
{
	//// internal
	@:optional var path:String;
	@:optional var validScore:Bool;

	////
	@:optional var song:String;
	@:optional var bpm:Float;
	@:optional var speed:Float;
	@:optional var notes:Array<SwagSection>;
	@:optional var events:Array<Array<Dynamic>>;
	@:optional var songNameChinese:String;//rce lmfao
	@:optional var songName:String;
	@:optional var tracks:SongTracks; // currently used
	@:noCompletion @:optional var extraTracks:Array<String>; // old te
	@:noCompletion @:optional var needsVoices:Bool; // fnf
	@:noCompletion @:optional var playerVocalFiles:Array<String>; // old rce
	@:noCompletion @:optional var opponentVocalFiles:Array<String>; // old rce
	@:noCompletion @:optional var sfxFiles:Array<String>; // old rce
	@:noCompletion @:optional var songFileNames:Array<String>; // old rce
	@:optional var player1:String;
	@:optional var player2:String;
	@:optional var player3:String;
	@:optional var gfVersion:String;
	@:optional var stage:String;
    @:optional var hudSkin:String;
	@:optional var igorAutoFix:Null<Bool>;
	@:optional var strums:Null<Int>;
	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
	@:optional var composer:String;
	@:optional var charter:String;
	//// Used for song info showed on the pause menu
	@:optional var info:Array<String>;
	@:optional var metadata:SongCreditdata;
	@:optional var keyCount:Int;
    @:optional var offset:Float; // Offsets the chart
}

typedef SongTracks = {
	var inst:Array<String>;
	var ?player:Array<String>;
	var ?opponent:Array<String>;
} 

typedef SongCreditdata = // beacuse SongMetadata is stolen
{
	?artist:String,
	?charter:String,
	?modcharter:String,
	?songNames:Array<SongName>,
	?extraInfo:Array<String>
}
typedef SongName = {
	var lang:String;
	var name:String;
}
class Song
{
	#if moonchart
    private static function findFormat(filePaths:Array<String>) {
        var files:Array<String> = [];
		for (path in filePaths) {
			if (Paths.exists(path)) 
				files.push(path);
		}

		if (files.length == 0)
			return null;
		
		var data:Null<Format> = null;
        try{
			data = FormatDetector.findFormat(files);
        }catch(e:Any){
            data = null;
        }
        return data;
    }

	public static var moonchartExtensions(get, null):Array<String> = [];
	static function get_moonchartExtensions(){
		if (moonchartExtensions.length == 0){
			for (key => data in FormatDetector.formatMap)
				if (!moonchartExtensions.contains(data.extension))
					moonchartExtensions.push(data.extension);
		}
		return moonchartExtensions;
	}

	static function isAMoonchartRecognizedFile(fileName:String) {
		// return moonchartExtensions.contains(Path.extension(fileName)); // short and elegant, probably slow too

		for (ext in moonchartExtensions) {
			if (fileName.endsWith('.$ext'))
				return true;
		}
		
		return false;
	}
	#end

	public static function getCharts(metadata:SongMetadata):Array<String>
	{
		Paths.currentModDirectory = metadata.folder;
		
        #if moonchart
		final songName = Paths.formatToSongPath(metadata.songName);

        var folder:String = '';
        var charts:Map<String, Bool> = [];
		
		function processFileName(unprocessedName:String) {
			var fileName:String = unprocessedName.toLowerCase();
			var filePath:String = folder + unprocessedName;

			if (!isAMoonchartRecognizedFile(fileName))
				return;

            var fileFormat:Format = findFormat([filePath]);
			if (fileFormat == null) return;

            switch (fileFormat) {
				case FNF_VSLICE:
					var woExtension:String = Path.withoutExtension(filePath);
					var diff = '';
					if (fileName.startsWith('$songName-chart-')){
						var split = woExtension.split("-");
						split.shift();
						diff = '-' + split.join("-");
					}
				var chartsFilePath:String = folder + songName + '-chart' + diff + '.json';
				var metadataPath:String = folder + songName + '-metadata' + diff + '.json';
				trace(chartsFilePath);
				var chart = new moonchart.formats.fnf.FNFVSlice().fromFile(chartsFilePath, metadataPath);
				for (diff in chart.diffs) charts.set(diff, true);
                case FNF_LEGACY_PSYCH | FNF_LEGACY:
                    if (fileName == '$songName.json') {
                        charts.set("normal", true);
                        return;
					} 
					else if (fileName.startsWith('$songName-')) {
						final extension_dot = songName.length + 1;
						charts.set(fileName.substr(extension_dot, fileName.length - extension_dot - 5), true);
						return;
					}
					
				default:
					var formatInfo:FormatData = FormatDetector.getFormatData(fileFormat);
					var chart:moonchart.formats.BasicFormat<{}, {}>;
					chart = Type.createInstance(formatInfo.handler, []).fromFile(filePath);
					var woExtension:String = Path.withoutExtension(filePath);
					if (chart.formatMeta.supportsDiffs || chart.diffs.length > 0){
						for (diff in chart.diffs)
							charts.set(diff, true);
						return;
					}else{
					if (woExtension.startsWith('$songName-')){
							var split = woExtension.split("-");
							split.shift();
							var diff = split.join("-");
							if (!charts.exists(diff))
							charts.set(diff, true);
							return;
						}
					}

			}
		}

		if (metadata.folder == "") {
			folder = Paths.getPreloadPath('songs/$songName/');
			Paths.iterateDirectory(folder, processFileName);
		}
		#if MODS_ALLOWED
		else {
			////
			var spoon:Array<String> = [];
			var crumb:Array<String> = [];
			var vslicespecial:Array<Array<String>> = [];

			folder = Paths.mods('${metadata.folder}/songs/$songName/');
			Paths.iterateDirectory(folder, (fileName)->{
				if (isAMoonchartRecognizedFile(fileName)){
					spoon.push(folder+fileName);
					crumb.push(fileName);
				}
			});
	
			for (fileName in crumb) {
				if ((fileName.startsWith('$songName-chart-')
				&&
				crumb.contains('$songName-metadata-'+fileName.substr('$songName-chart-'.length,fileName.length)))
				|| (fileName.startsWith('$songName-chart.json') && crumb.contains('$songName-metadata.json')))
				{
					var vsliceShit = [];
					vsliceShit.push(fileName);

					if (crumb.contains('$songName-metadata-'+fileName.substr('$songName-chart-'.length,fileName.length))){
					vsliceShit.push('$songName-metadata-'+fileName.substr('$songName-chart-'.length,fileName.length));
					crumb.remove(fileName);
					crumb.remove('$songName-metadata-'+fileName.substr('$songName-chart-'.length,fileName.length));
					}
					else if (crumb.contains('$songName-metadata.json')){
					vsliceShit.push('$songName-metadata.json');
					crumb.remove(fileName);
					crumb.remove('$songName-metadata.json');
					}
					if (vsliceShit.length > 0)
					{
						var woExtension:String = Path.withoutExtension(folder+vsliceShit[0]);
						var diff = '';

				var chartsFilePath:String = folder + vsliceShit[0];
				var metadataPath:String = folder + vsliceShit[1];
				trace(chartsFilePath);
				var chart = new moonchart.formats.fnf.FNFVSlice().fromFile(chartsFilePath, metadataPath);
				for (diff in chart.diffs) if (!charts.exists(diff))charts.set(diff, true);
					}else{
						processFileName(fileName);
					}
				}
				else
				processFileName(fileName);

			}

			////
			#if PE_MOD_COMPATIBILITY
			folder = Paths.mods('${metadata.folder}/data/$songName/');
			Paths.iterateDirectory(folder, processFileName);
			#end
		}
		#end
		

		return [for (name in charts.keys()) name];
        #else
		final songName = Paths.formatToSongPath(metadata.songName);
		final charts = new haxe.ds.StringMap();
		
		function processFileName(unprocessedName:String)
		{		
			var fileName:String = unprocessedName.toLowerCase();
            if (fileName == '$songName.json'){
				charts.set("normal", true);
				return;
			}
			else if (!fileName.startsWith('$songName-') || !fileName.endsWith('.json')){
				return;
			}

			final extension_dot = songName.length + 1;
			charts.set(fileName.substr(extension_dot, fileName.length - extension_dot - 5), true);
		}


		if (metadata.folder == "")
		{
			#if PE_MOD_COMPATIBILITY
			Paths.iterateDirectory(Paths.getPreloadPath('data/$songName/'), processFileName);
			#end
			Paths.iterateDirectory(Paths.getPreloadPath('songs/$songName/'), processFileName);
		}
		#if MODS_ALLOWED
		else
		{
			#if PE_MOD_COMPATIBILITY
			Paths.iterateDirectory(Paths.mods('${metadata.folder}/data/$songName/'), processFileName);
			#end
			Paths.iterateDirectory(Paths.mods('${metadata.folder}/songs/$songName/'), processFileName);
		}
		#end
        
		return [for (name in charts.keys()) name];
        #end
	}
	static function searchJson(song:String,diff:String='',folder:String = ''):String
	{
		var path:String = Paths.formatToSongPath(folder) + '/' + Paths.formatToSongPath(song) + diff + '.json';
		var fullPath = Paths.getPath('songs/$path', false);
		
		#if PE_MOD_COMPATIBILITY
		if (!Paths.exists(fullPath))
			fullPath = Paths.getPath('data/$path', false);
		#end
		return fullPath;
	}
	public static function loadFromJson(jsonInput:String, diff:String = '',folder:String, ?isSongJson:Bool = true):Null<SwagSong>
	{
		var diffs = '';
		if (diff == 'normal')
			diffs = '';
		else
			diffs = '-'+diff;
		
		var fullPath = searchJson(jsonInput,diffs,folder);
		if (!Paths.exists(fullPath) && diffs != '')
			fullPath = searchJson(jsonInput,'',folder);
		var rawJson:Null<String> = Paths.getContent(fullPath);
		if (rawJson == null){
			trace('song JSON file not found!'+fullPath);
			return null;
		}
		
		// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		rawJson = rawJson.trim();
		while (!rawJson.endsWith("}"))
			rawJson = rawJson.substr(0, rawJson.length - 1);

		var songJson:SwagSong = parseJSONshit(rawJson);
		if (isSongJson != false) onLoadJson(songJson,diff);
		validlizeFormatShits(songJson);
		songJson.path = fullPath; 
		return songJson;
	}

	public static function onLoadEvents(songJson:Dynamic){
		if(songJson.events == null){
			songJson.events = [];
			
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				var i:Int = 0;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if (note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		return songJson;
	}

	public static function validlizeFormatShits(songJson:Dynamic){
		var swagJson:SwagSong = songJson;
		if (swagJson.validScore == null) 
			swagJson.validScore = true;

		if (swagJson.path == null) 
			swagJson.path = '';
		return swagJson;
	}
	/** sanitize/update json values to a valid format**/
	private static function onLoadJson(songJson:Dynamic,diff:String = '')
	{
		var swagJson:SwagSong = songJson;

		onLoadEvents(songJson);

		////
		if (songJson.gfVersion == null){
			if (songJson.player3 != null){
				songJson.gfVersion = songJson.player3;
				songJson.player3 = null;
			}
			else
				songJson.gfVersion = "gf";
		}
		if (songJson.metadata == null){
		if (songJson.songName != null || 
			swagJson.songNameChinese != null || 
			swagJson.composer != null || 
			swagJson.charter != null){
			swagJson.metadata = {};
			if (swagJson.songName != null && swagJson.songNameChinese != null){
				var songNames = [];

				if (swagJson.songName != null){
				var songName:SongName = 
				{
					lang:Paths.locale,
				name:swagJson.songName
				};
				songNames.push(songName);
				swagJson.songName = null;
				}
				if (swagJson.songNameChinese != null){
				var songName:SongName = 
				{
					lang:'zh-cn',
				name:swagJson.songName
				};
				songNames.push(songName);
				swagJson.songNameChinese = null;
				}
				swagJson.metadata.songNames = songNames;
			}
			if (swagJson.composer != null){
				swagJson.metadata.artist = swagJson.composer;
				swagJson.composer == null;
			}
			if (swagJson.charter != null){
				swagJson.metadata.charter = swagJson.charter;
				swagJson.charter == null;
			}
		}
		}
		//// new tracks system
		if (swagJson.tracks == null) {
			var instTracks:Array<String> = ["Inst"];

			////
			var playerTracks:Array<String> = null;
			var opponentTracks:Array<String> = null;

			/**
			 * 1. If 'needsVoices' is false, no tracks will be defined for the player or opponent
			 * 2. If the chart folder couldn't be retrieved then "Voices-Player" and "Voices-Opponent" are used
			 * 3. If a "Voices-Player" exists then it is defined as a player track, otherwise "Voices" is used
			 * 4. If a "Voices-Opponent" exists then it is defined as an opponent track, otherwise "Voices" is used
			 */
			inline function sowy() {
				//// 1
				if (!swagJson.needsVoices) {
					playerTracks = [];
					opponentTracks = [];
					return false;
				}

				//// 2
				if (swagJson.path==null) return true;
				var jsonPath:Path = new Path(swagJson.path
                    #if PE_MOD_COMPATIBILITY
                    .replace("data/", "songs/")
                    #end);

				var folderPath = jsonPath.dir;
				if (folderPath == null) return true; // probably means that it's on the same folder as the exe but fuk it

				//// 3 and 4
				inline function existsInFolder(name)
					return Paths.exists(Path.join([folderPath, name]));

				var defaultVoices = existsInFolder('Voices.ogg') ? ["Voices"] : [];

				inline function voiceTrack(name)
					return existsInFolder('$name.ogg') ? [name] : defaultVoices;
				
				var trackName = 'Voices-${swagJson.player1}';
				playerTracks = existsInFolder('$trackName.ogg') ? [trackName] : voiceTrack("Voices-Player");

				var trackName = 'Voices-${swagJson.player2}';
				opponentTracks =  existsInFolder('$trackName.ogg') ? [trackName] : voiceTrack("Voices-Opponent");

				return false;
			}
			if (sowy()) {
				if (swagJson.playerVocalFiles != null && swagJson.songFileNames != null) {
					for (name in swagJson.playerVocalFiles)
						playerTracks.push(swagJson.songFileNames[1] + '-' + name);
					swagJson.playerVocalFiles = null;
				}else{
				playerTracks = ["Voices"];
				
				}
				if (swagJson.opponentVocalFiles != null && swagJson.songFileNames != null) {
					for (name in swagJson.opponentVocalFiles)
						swagJson.opponentVocalFiles.push(swagJson.songFileNames[1] + '-' + name);
					swagJson.opponentVocalFiles = null;
				}else{
				opponentTracks = ["Voices"];
				}
				if (swagJson.songFileNames != null) instTracks = [swagJson.songFileNames[0]];
				if (swagJson.extraTracks != null) {
					for (name in swagJson.extraTracks)
						instTracks.push(name);
					swagJson.extraTracks = null;
				}
				if (swagJson.sfxFiles != null) {
					for (name in swagJson.sfxFiles)
						instTracks.push(name);
					swagJson.sfxFiles = null;
				}
				if (swagJson.songFileNames != null)
				{
					swagJson.songFileNames = null;
				}
			}
			for (tracks in instTracks){
				if (Paths.exists('songs/${swagJson.song}/$tracks-'+diff+'.ogg'))
					tracks = '$tracks-'+diff+'.ogg';
				}
				for (tracks in playerTracks){
				if (Paths.exists('songs/${swagJson.song}/$tracks-'+diff+'.ogg'))
					tracks = '$tracks-'+diff+'.ogg';
				}
				for (tracks in opponentTracks){
				if (Paths.exists('songs/${swagJson.song}/$tracks-'+diff+'.ogg'))
					tracks = '$tracks-'+diff+'.ogg';
				}
			////
			swagJson.tracks = {inst: instTracks, player: playerTracks, opponent: opponentTracks};
		}

        if (swagJson.notes == null)
            swagJson.notes = [];
        
        if(swagJson.notes.length == 0)
            swagJson.notes.push({
                sectionNotes: [],
                typeOfSection: 0,
                mustHitSection: true,
                gfSection: false,
                bpm: 0,
                changeBPM: false,
                altAnim: false,
                sectionBeats: 4
            });
        
        for(section in swagJson.notes){
			for (note in section.sectionNotes){
                if(note[3] == 'Hurt Note')
                    note[3] = 'Mine';
            }
        }

		////
		if (swagJson.arrowSkin == null || swagJson.arrowSkin.trim().length == 0 || swagJson.arrowSkin == '')
			swagJson.arrowSkin = "NOTE_assets";

		if (swagJson.splashSkin == null || swagJson.splashSkin.trim().length == 0 || swagJson.splashSkin == '')
			swagJson.splashSkin = "noteSplashes";

		if (swagJson.hudSkin==null)
			swagJson.hudSkin = 'default';

		if (swagJson.igorAutoFix == null)
			swagJson.igorAutoFix = false;

		if (swagJson.strums == null) 
			swagJson.strums = 2;
		
		
		if (swagJson.keyCount == null) 
			swagJson.keyCount = 4;


		return swagJson;
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var data = Json.parse(rawJson);
		var swagShit:SwagSong = cast data.song;
		if (Std.isOfType(Reflect.getProperty(data,'song'),String))//HI
			swagShit = cast data;
		return swagShit;
	}
	public static function characterCheck(fuck:String){
		switch(fuck){
			case 'pico-playable' | 'pico-player':
				fuck = 'pico';
		}
		return fuck;
	}
	static function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.t, Obj2.t);
	//MOONCHART SUSTAIN BUGGED RIP
	static function getFunkinVsliceChart(daSong:String = '', ?folder:String = '',difficu:String = 'normal',filePath:Array<String> = null){
		var songJsonDA = null;
		var metaDataDA = null;
		var songJson = null;
		var metaData = null;
		trace(difficu);
		trace(filePath);
		if (filePath != null){
		songJsonDA = filePath[0];
		metaDataDA = filePath[1];
		}else{
		songJsonDA = searchJson(daSong,'-chart-'+difficu.toLowerCase(),folder);
		metaDataDA = searchJson(daSong,'-metadata-'+difficu.toLowerCase(),folder);
		
		if (!Paths.exists(songJsonDA))
			songJsonDA = searchJson(daSong,'-chart',folder);
		if (!Paths.exists(metaDataDA))
			metaDataDA = searchJson(daSong,'-metadata',folder);
		}
		trace(songJsonDA);
			try{
			songJson = Paths.getJson(songJsonDA);
			metaData = Paths.getJson(metaDataDA);
		}catch(e){
			trace('VSLICE CHARTING FILE ERRORED! USING LEGACY ONE...');
			if (difficu.toLowerCase() == 'normal' || difficu == '')
				difficu = '';
			else
				difficu = '-'+difficu;
			return loadFromJson(daSong,difficu.toLowerCase(),folder);
			}
			var playData = Reflect.getProperty(metaData,'playData');
			var charData = Reflect.getProperty(playData,'characters');
			var stage:Null<String> = Reflect.getProperty(playData,'stage');
			switch(stage) //Psych and VSlice use different names for some stages
			{
				case 'mainStage':
					stage = 'stage';
				case 'spookyMansion':
					stage = 'spooky';
				case 'phillyTrain':
					stage = 'philly';
				case 'limoRide':
					stage = 'limo';
				case 'mallXmas':
					stage = 'mall';
				case 'tankmanBattlefield':
					stage = 'tank';
			}
			var II = '';
			if (Reflect.hasField(charData,'instrumental'))
				II += '-'+Reflect.getProperty(charData,'instrumental');
			var III = '';
			if (Reflect.hasField(charData,'voices'))
				III += '-'+Reflect.getProperty(charData,'voices');
			else if (Reflect.hasField(charData,'instrumental'))
				III += '-'+Reflect.getProperty(charData,'instrumental');
			var instFile = 'Inst';
			var playerFile = 'Voices';
			if (Paths.exists(Paths.returnSoundPath('songs','${Paths.formatToSongPath(daSong)}/'+instFile+II)))
				instFile += II;
			if (Paths.exists(
				Paths.returnSoundPath(
				'songs',
				'${Paths.formatToSongPath(daSong)}/'
				+playerFile
				+'-${Reflect.getProperty(charData,'player')}'
				))
				||
				Paths.exists(
				Paths.returnSoundPath(
					'songs',
					'${Paths.formatToSongPath(daSong)}/'
					+playerFile
					+'-${Reflect.getProperty(charData,'player')}'
					+ III
					))
				)
				playerFile = playerFile + '-'+Reflect.getProperty(charData,'player');
			
				if (Paths.exists(Paths.returnSoundPath('songs','${Paths.formatToSongPath(daSong)}/'+playerFile+III)))
				playerFile += II;
			var opponentFile = 'Voices';
			if (Paths.exists(
				Paths.returnSoundPath(
				'songs',
				'${Paths.formatToSongPath(daSong)}/'
				+opponentFile
				+'-${Reflect.getProperty(charData,'opponent')}'
				))
				||
				Paths.exists(
				Paths.returnSoundPath(
					'songs',
					'${Paths.formatToSongPath(daSong)}/'
					+opponentFile
					+'-${Reflect.getProperty(charData,'opponent')}'
					+ III
					))
				)
				opponentFile = opponentFile + '-'+Reflect.getProperty(charData,'opponent');
			if (Paths.exists(Paths.returnSoundPath('songs','${Paths.formatToSongPath(daSong)}/'+opponentFile+III)))
				opponentFile += II;
			var timeChanges = Reflect.getProperty(metaData,'timeChanges');
			var data:SwagSong = {
				song: daSong,
				notes: [],
				events: [],
				tracks:{ 
				inst:[instFile],
				player:[playerFile],
				opponent:[opponentFile],
				},
				sfxFiles: [],
				bpm: timeChanges[0].bpm,
				needsVoices: true,
				igorAutoFix: true,
				hudSkin:'default',
				arrowSkin: '',
				splashSkin: 'noteSplashes',//idk it would crash if i didn't
				player1: Reflect.getProperty(charData,'player'),
				player2: Reflect.getProperty(charData,'opponent'),
				gfVersion: Reflect.getProperty(charData,'girlfriend'),
				speed: Reflect.getProperty(Reflect.getProperty(songJson,'scrollSpeed'),difficu.toLowerCase()),
				stage: stage,
				validScore: false,
				strums: 2,
				metadata:{
					artist:Reflect.getProperty(metaData,'artist'),
					charter:Reflect.getProperty(metaData,'charter'),
					songNames:[{lang:Paths.locale,name:Reflect.getProperty(metaData,'songName')}]
				}
				
			};
			var varies = '';
			if (Reflect.hasField(charData,'instrumental'))
				varies = Reflect.getProperty(charData,'instrumental');
			Reflect.setProperty(data,'vary',varies);
			var lastNoteTime:Float = 0;
			if (Reflect.hasField(songJson.notes,difficu.toLowerCase()))
				{
                    var lmfao:Array<Dynamic> = Reflect.getProperty(songJson.notes,difficu.toLowerCase());
					var lastNote:Dynamic = lmfao[lmfao.length - 1];
					if(lmfao.length > 0 && lastNote.t > lastNoteTime)
						lastNoteTime = lastNote.t;

					var sectionData:Array<SwagSection> = [];
					for (fuckyou in lmfao){
						if (fuckyou.l == null)fuckyou.l = 0;
						if (fuckyou.k == null)fuckyou.k = '';
						var kind = fuckyou.k;
						switch (kind.toLowerCase()){
							case 'normal':
								kind = '';
						}
						//sec.sectionNotes.push([fuckyou.t,fuckyou.d,fuckyou.l,kind]);
					}
					var sectionMustHits:Array<Bool> = [];

		var focusCameraEvents:Array<Dynamic> = [];
		var allEvents:Array<Dynamic> = songJson.events;
		if(allEvents != null && allEvents.length > 0)
		{
			var time:Float = 0;
			allEvents.sort(sortByTime);

			focusCameraEvents = allEvents.filter((event:Dynamic) -> event.e == 'FocusCamera' && (event.v == 0 || event.v == 1 || event.v.char != null));
			if(focusCameraEvents.length > 0)
			{
				var focusEventNum:Int = 0;
				var lastMustHit:Bool = false;
				while(time < focusCameraEvents[focusCameraEvents.length - 1].t)
				{
					var bpm:Float = timeChanges[0].bpm;
					var sectionTime:Float = 0;
					if(timeChanges.length > 0)
					{
						for (bpmChange in timeChanges)
						{
							if(time < bpmChange.t) break;
							bpm = bpmChange.bpm;
						}
					}

					for (i in focusEventNum...focusCameraEvents.length)
					{
						var focusEvent = focusCameraEvents[i];
						if(time+1 < focusEvent.t)
						{
							focusEventNum = i;
							break;
						}
						
						var char:Dynamic = focusEvent.v.char;
						if(char != null)
							char = Std.string(char);
						else
							char = Std.string(focusEvent.v);

						if(char == null) char = '1';
						lastMustHit = (char == '0');
					}
					sectionMustHits.push(lastMustHit);
					sectionTime = Conductor.calculateCrochet(bpm) * 4;
					time += sectionTime;
				}
			}
		}
		if(sectionMustHits.length < 1) sectionMustHits.push(false);
						
						var baseSections:Array<SwagSection> = [];
						var sectionTimes:Array<Float> = [];
						var bpm:Float =  timeChanges[0].bpm;
						var lastBpm:Float =  timeChanges[0].bpm;
						var time:Float = 0;
						while (time < lastNoteTime)
						{
							var sectionTime:Float = 0;
							if(timeChanges.length > 0)
							{
								for (bpmChange in timeChanges)
								{
									if(time < bpmChange.t) break;
									bpm = bpmChange.bpm;
								}
							}
							sectionTime = Conductor.calculateCrochet(bpm) * 4;
							sectionTimes.push(time);
							time += sectionTime;
				
							var sec:SwagSection = {
								sectionBeats: 4.0,
								bpm: lastBpm,
								changeBPM: false,
								mustHitSection: true,
								gfSection: false,
								sectionNotes: [],
								typeOfSection: 0,
								altAnim: false
						};		
						sec.mustHitSection = sectionMustHits[baseSections.length >= sectionMustHits.length ? sectionMustHits.length - 1 : baseSections.length];
							if(lastBpm != bpm)
							{
								sec.changeBPM = true;
								sec.bpm = bpm;
								lastBpm = bpm;
							}
							baseSections.push(sec);
						}

						for (section in baseSections) //clone sections
							{
								var sec:SwagSection = {
									sectionBeats: 4.0,
									bpm: section.bpm,
									changeBPM: false,
									mustHitSection: true,
									gfSection: false,
									sectionNotes: [],
									typeOfSection: 0,
									altAnim: false
							};		
								sec.mustHitSection = section.mustHitSection;
								if(Reflect.hasField(section, 'changeBPM'))
								{
									sec.changeBPM = section.changeBPM;
									sec.bpm = section.bpm;
								}
								sectionData.push(sec);
							}
				
							var noteSec:Int = 0;
							var time:Float = 0;
							for (note in lmfao)
							{
								while(noteSec + 1 < sectionTimes.length && sectionTimes[noteSec + 1] <= note.t)
									noteSec++;
				
								var normalNote:Array<Dynamic> = [note.t, note.d, (note.l != null ? note.l : 0)];
								if(note.k != null && note.k.length > 0 && note.k != 'normal') {
									switch (note.k){
										case 'mom':
											note.k = 'Alt Animation';
									}
									normalNote.push(note.k);
								}
				
								if(sectionData[noteSec] != null)
									sectionData[noteSec].sectionNotes.push(normalNote);
							}
							data.notes = sectionData;
							var ev:Array<Dynamic> = allEvents;

							var eventList:Map<String,Array<Array<String>>> = new Map<String,Array<Array<String>>>();
						for (fuckyou in ev){
							var value1 = '';
							var value2 = '';
							var value3 = '';

						    var values:Array<String> = Reflect.fields(fuckyou.v);
						
							switch (fuckyou.e){
							
								default:
							switch (values.length){
								case 1:
								value1 = Std.string(Reflect.field(fuckyou.v,values[0]));
								case 2:
									value1 = Std.string(Reflect.field(fuckyou.v,values[0]));
									value2 = Std.string(Reflect.field(fuckyou.v,values[1]));
								case 3:
									value1 = Std.string(Reflect.field(fuckyou.v,values[0]));
									value2 = Std.string(Reflect.field(fuckyou.v,values[1]));
									value3 = Std.string(Reflect.field(fuckyou.v,values[2]));
									
							}
							}
						
							if (fuckyou.e != 'FocusCamera'){
						if (!eventList.exists(Std.string(fuckyou.t)))
							eventList.set(Std.string(fuckyou.t),[]);

						eventList.get(Std.string(fuckyou.t)).push([fuckyou.e,value1,value2,value3]);
										}
					}
					
					for (i in eventList.keys())
					data.events.push([Std.parseFloat(i),eventList.get(i)]);
				}else{
					trace('VSLICE FILES DO NOT CONTAIN DIFFICULTY: '+difficu);
			if (difficu.toLowerCase() == 'normal' || difficu == '')
				difficu = '';
			else
				difficu = '-'+difficu;
			return loadFromJson(daSong,difficu.toLowerCase(),folder); 
				}
					return data;
	}
	static public function loadSong(metadata:SongMetadata, ?difficulty:String, ?difficultyIdx:Int = 1) {
		Paths.currentModDirectory = metadata.folder;

		var songLowercase:String = Paths.formatToSongPath(metadata.songName);
		var diffSuffix:String;

        var rawDifficulty:String = difficulty;

		if (difficulty == null || difficulty == "" || difficulty == "normal"){
			difficulty = 'normal';
			diffSuffix = '';
		}else{
			difficulty = difficulty.trim().toLowerCase();
			diffSuffix = '-$difficulty';
		}
				
		if (Main.showDebugTraces)
			trace('playSong', metadata, difficulty);
		
		#if (moonchart)
		var SONG:Null<SwagSong> = null;

		var isVSlice:Bool = false;
		if (metadata.folder != ""){
			var spoon:Array<String> = [];
			var crumb:Array<String> = [];
			var vslicespecial:Array<Array<String>> = [];
			var folder = Paths.mods('${metadata.folder}/songs/$songLowercase/');
			Paths.iterateDirectory(folder, (fileName)->{
				if (isAMoonchartRecognizedFile(fileName)){
					spoon.push(folder+fileName);
					crumb.push(fileName);
				}
			});
	
			for (fileName in crumb) {
				if ((fileName.startsWith('$songLowercase-chart-')
				&&
				crumb.contains('$songLowercase-metadata-'+fileName.substr('$songLowercase-chart-'.length,fileName.length)))
				|| (fileName.startsWith('$songLowercase-chart.json') && crumb.contains('$songLowercase-metadata.json')))
				{
					var vsliceShit = [];
					vsliceShit.push(fileName);

					if (crumb.contains('$songLowercase-metadata-'+fileName.substr('$songLowercase-chart-'.length,fileName.length))){
					vsliceShit.push('$songLowercase-metadata-'+fileName.substr('$songLowercase-chart-'.length,fileName.length));
					crumb.remove(fileName);
					crumb.remove('$songLowercase-metadata-'+fileName.substr('$songLowercase-chart-'.length,fileName.length));
					}
					else if (crumb.contains('$songLowercase-metadata.json')){
					vsliceShit.push('$songLowercase-metadata.json');
					crumb.remove(fileName);
					crumb.remove('$songLowercase-metadata.json');
					}
					if (vsliceShit.length > 0)
					{
						var woExtension:String = Path.withoutExtension(folder+vsliceShit[0]);
						var diff = '';

				var chartsFilePath:String = folder + vsliceShit[0];
				var metadataPath:String = folder + vsliceShit[1];
				trace(chartsFilePath);
				var chart = new moonchart.formats.fnf.FNFVSlice().fromFile(chartsFilePath, metadataPath);

					if (chart.diffs.contains(rawDifficulty)){
						trace("CONVERTING FROM VSLICE AAAAAAAAAAAAAAAGGHGD");
						isVSlice = true;
	
						SONG = getFunkinVsliceChart(songLowercase,songLowercase,rawDifficulty,[chartsFilePath,metadataPath]);
					}else{
						trace('VSLICE FILES DO NOT CONTAIN DIFFICULTY: $rawDifficulty');
					}
					}
				}
		}
	}
		
		if (!isVSlice) {
			// TODO: scan through the song folder and look for the first thing that has a supported extension (if json then check if it has diffSuffix cus FNF formats!!)
			// Or dont since this current method lets you do a dumb thing AKA have 2 diff chart formats in a folder LOL
			for (ext in moonchartExtensions) {
				var files:Array<String> = [songLowercase + diffSuffix, songLowercase];
				for (idx in 0...files.length){
					var input = files[idx];
					var path:String = Paths.formatToSongPath(songLowercase) + '/' + Paths.formatToSongPath(input) + '.' + ext;
					var filePath:String = Paths.getPath("songs/" + path);
					var fileFormat:Format = findFormat([filePath]);
					#if PE_MOD_COMPATIBILITY
					if (fileFormat == null){
						filePath = Paths.getPath("data/" + path);
						fileFormat = findFormat([filePath]);
					}
					#end
					if (fileFormat != null){
						var format:Format = fileFormat;
						var formatInfo:Null<FormatData> = FormatDetector.getFormatData(format);
						SONG = switch(format){
							case FNF_LEGACY_PSYCH | FNF_LEGACY | "FNF_TROLL":
								Song.loadFromJson(songLowercase, difficulty,songLowercase);
								
							default:
								trace('Converting from format $format!');

								var chart:moonchart.formats.BasicFormat<{}, {}>;
								chart = Type.createInstance(formatInfo.handler, []);
								chart = chart.fromFile(filePath);
								if(chart.formatMeta.supportsDiffs && !chart.diffs.contains(rawDifficulty))continue;

								var converted = new SupportedFormat().fromFormat(chart, rawDifficulty);
								var chart:SwagSong = cast converted.data.song;
								chart.path = filePath;
								chart.song = songLowercase;
								onLoadJson(chart,rawDifficulty);
						}
						break;
					}
				}
				if (SONG != null)
					break;
			}
		}

		if (SONG == null){
            trace("No file format found for the chart!");
            // Find a better way to show the error to the user
            return;
        }
		#else
		var SONG:SwagSong = Song.loadFromJson(songLowercase, difficulty, songLowercase);
		#end

		PlayState.SONG = SONG;
		PlayState.difficulty = difficultyIdx;
		PlayState.difficultyName = difficulty;
		PlayState.isStoryMode = false;	
	}

	static public function switchToPlayState()
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.volume = 0;

		LoadingState.loadAndSwitchState(new PlayState());	
	}

	static public function playSong(metadata:SongMetadata, ?difficulty:String, ?difficultyIdx:Int = 1)
	{
		loadSong(metadata, difficulty, difficultyIdx);
		switchToPlayState();
	} 
}

@:structInit
class SongMetadata
{
	public var songName:String = '';
	public var folder:String = '';
	public var charts(get, null):Array<String>;
	function get_charts()
		return (charts == null) ? charts = Song.getCharts(this) : charts;

	public function new(songName:String, ?folder:String = '')
	{
		this.songName = songName;
		this.folder = folder != null ? folder : '';
	}

	public function play(?difficultyName:String = ''){
        if(charts.contains(difficultyName))
			return Song.playSong(this, difficultyName, charts.indexOf(difficultyName));
    
        trace("Attempt to play null difficulty: " + difficultyName);
    }

	public function toString()
		return '$folder:$songName';
}