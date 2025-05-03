package funkin.states;

import funkin.data.Highscore;
import flixel.math.FlxMath;
import funkin.states.FreeplayState;
import funkin.data.Song;
import funkin.data.Song.SongMetadata;
import funkin.data.WeekData;
import funkin.data.WeekData.WeekMetadata;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSort;
typedef Cate = {name:String,data:Array<WeekMetadata>}

class FreeplayCategoryState extends MusicBeatState
{
	public static var categoriesAmount:Int = 0;
	public static var categories = new Map<String,Cate>();
	var menu = new AlphabetMenu();
	var weekMeta:Array<Array<WeekMetadata>> = [];
	public static var displayAutoTrace:Bool = false;
	var bgGrp = new FlxTypedGroup<FlxSprite>();
	var bg:FlxSprite;

	var targetHighscore:Float = 0.0;
	var lerpHighscore:Float = 0.0;

	var targetRating:Float = 0.0;
	var lerpRating:Float = 0.0;

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;

	static var lastSelected:Int = 0;

	var selectedWeekData:Array<WeekMetadata> = [];
	
	var hintText:FlxText;
	public static function getCategories(){
		categories.clear();
		categoriesAmount = 0;
	for (mod => daJson in Paths.getContentMetadata())
		{
			for (cates in 0...daJson.freeplayCategories.length){
				var cate = daJson.freeplayCategories[cates];
				if (!categories.exists(cate.id)){
					funkin.states.FreeplayCategoryState.categoriesAmount++;
					var num:Int = cates;
					var data = {name:cate.name,data:[]};
					Reflect.setProperty(data,'id',num);
					categories.set(cate.id,data);
				}
				var da=categories.get(cate.id);
				var weeks = da.data;
				for (week in funkin.data.WeekData.reloadWeekFiles(true))
					{
						if (week.freeplayCategory == cate.id){
							weeks.push(week);
						}
					}
					categories.set(cate.id,da);
			}
			
		}
	}
	public static function initCategory():Array<Dynamic>{
		categories.set('all',{name:"All Songs",data:WeekData.reloadWeekFiles(true)});
		/*for (voj in categories.iterator()){
			menu.addTextOption(voj.name).ID = Reflect.getProperty(voj,'id');
			weekMeta.push(voj.data);
		}
		function sortings(Obj1:funkin.objects.Alphabet, Obj2:funkin.objects.Alphabet)
		{
			return FlxSort.byValues(FlxSort.ASCENDING, Obj1.ID, Obj2.ID);
		}*/
		var weekMetas:Array<Array<WeekMetadata>> = [];
		var menus = new AlphabetMenu();
		var catePushed:Array<String> = [];
		for (folder in Paths.getMergeFolders()){
			if (Paths.exists(folder + 'categoryList.txt')){
				var voj = funkin.CoolUtil.coolTextFile(folder + 'categoryList.txt');
			
				for (name in voj){
				if (categories.exists(name) && !catePushed.contains(name)){
					var cate = categories.get(name);
					menus.addTextOption(cate.name).ID = Reflect.getProperty(cate,'id');
			weekMetas.push(cate.data);
			catePushed.push(name);
				}
				}
			}
		}
		menus.addTextOption(categories.get('all').name);
		weekMetas.push(categories.get('all').data);
		return [weekMetas,menus];
	}
	override public function create()
	{
		#if DISCORD_ALLOWED
		funkin.api.Discord.DiscordClient.changePresence('In the menus');
		#end
		getCategories();
		var cates = initCategory();
		weekMeta = cates[0];
		menu = cates[1];
		////
		bg = new FlxSprite();
		bg.loadGraphic(Paths.image('menuBGBlue'));
		bg.screenCenter();
		add(bgGrp);
		bgGrp.add(bg);
		add(menu);

		menu.controls = controls;
		menu.callbacks.onSelect = (selectedIdx) -> onSelectWeek(weekMeta[selectedIdx]);
		menu.callbacks.onAccept = onAccept;
		

		////
		menu.curSelected = lastSelected;
		super.create();
	}

	function onAccept(){

		if (selectedWeekData.length == 0 || noSong){
			if (!displayAutoTrace){
			if (noSong)
			{
				var t = 'NO SONGS ADDED!';
				createText(t);
				trace(t);
			}else if (selectedWeekData.length == 0){
				var t = 'NO WEEKS ADDED!';
				createText(t);
				trace(t);
			}else
			{
				var t = 'UNKNOWN ERROR!';
				createText(t);
				trace(t);
			}
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
		}
		else{
			menu.controls = null;

			MusicBeatState.switchState(new FreeplayState(selectedWeekData));
			//if (songLoaded != selectedSong)
			//	Song.loadSong(selectedSongData, curDiffStr, curDiffIdx);

		}
	}
	function createText(text){
		var text = new FlxText(0, 0, 0, text,60);
		text.screenCenter();
		add(text);
		text.moves = true;
		text.velocity.y = -80;
		FlxTween.tween(text,{alpha:0},1,{onComplete:function(twn){
			text.destroy();
		}});
	}
	// disable menu class controls for one update cycle Dx 
	var stunned:Bool = false;
	inline function stun(){
		stunned = true;
		menu.controls = null;
	}

	override public function update(elapsed:Float)
	{
		if (stunned){
			stunned = false;
			menu.controls = controls;
		}
		if (controls.BACK){
			menu.controls = null;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new funkin.states.MainMenuState());	
			
		}

		super.update(elapsed);
	}
	var noSong = false;
	function onSelectWeek(data:Array<WeekMetadata>)
	{	
		noSong = false;
		selectedWeekData = data;
		var ss= [];
		for (week in selectedWeekData)
			{
				if (week.songs != null){
					for (songName in week.songs){
					var metadata:SongMetadata = {songName: songName, folder: week.directory};
					ss.push(metadata);
					}
				}
			}
			if (ss.length == 0)
			noSong = true;
	//	trace(selectedWeekData);
	}

	override public function destroy()
	{
		lastSelected = menu.curSelected;
		
		super.destroy();
	}
}