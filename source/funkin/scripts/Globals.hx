package funkin.scripts;

import funkin.states.PlayState;
import funkin.states.GameOverSubstate;
import funkin.states.GameOverSubstateAlt;

class Globals
{
	public static final Function_Stop:Dynamic = 'FUNC_STOP';
	public static final Function_Continue:Dynamic = 'FUNC_CONT'; // i take back what i said
	public static final Function_Halt:Dynamic = 'FUNC_HALT';

	public static final variables:Map<String, Dynamic> = new Map(); // it MAKES WAY MORE SENSE FOR THIS TO BE HERE THAN IN PLAYSTATE GRRR BARK BARK

	public static inline function getInstance()
	{
		return PlayState.instance.isDead ? (PlayState.rhythmMode ?  GameOverSubstateAlt.instance: GameOverSubstate.instance) : PlayState.instance;
	}
}