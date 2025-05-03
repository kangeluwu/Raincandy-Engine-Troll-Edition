package funkin.states;

class StoryMenuState extends MusicBeatState{
    override function create(){
        MusicBeatState.switchState(new funkin.states.SongSelectState());
        super.create();
    }
}