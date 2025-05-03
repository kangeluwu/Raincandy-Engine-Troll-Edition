package funkin.modchart.modifiers;

import funkin.modchart.Modifier.ModifierOrder;
import funkin.modchart.*;
import math.*;

import flixel.FlxG;
import flixel.FlxSprite;
import funkin.objects.playfields.NoteField;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import math.*;
import flixel.math.FlxAngle;
import funkin.objects.NoteObject.ObjectType;
class ReverseModifier extends NoteModifier 
{
	inline function lerp(a:Float, b:Float, c:Float) 
		return a + (b - a) * c;

	override function getOrder() 
		return REVERSE;
	override function getName() 
		return 'reverse';

	override function shouldExecute(player:Int, val:Float)
		return true;
	override function ignoreUpdateNote()
		return false;

    public function getReverseValue(dir:Int, player:Int){
        var kNum = 4;
        var val:Float = 0;
        if(dir>=kNum * 0.5)
            val += getSubmodValue("split" ,player);

        if((dir%2)==1)
            val += getSubmodValue("alternate" ,player);

        var first = kNum * 0.25;
        var last = kNum-1-first;

        if(dir>=first && dir<=last)
            val += getSubmodValue("cross" ,player);

        val += getValue(player) + getSubmodValue("reverse" + Std.string(dir), player);


        if(getSubmodValue("unboundedReverse",player)==0){
            val %=2;
            if(val>1)val=2-val;
        }

       	if(ClientPrefs.downScroll)
            val = 1 - val;

        return val;
    }

	private inline function getCenterValue(player:Int){
		var centerPercent = getSubmodValue("centered", player);
		#if tgt
		return (ClientPrefs.midScroll) ? 1 - centerPercent : centerPercent;
		#else
		return centerPercent;
		#end
	}

	override function getPos(visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:NoteObject, field:NoteField)
	{
		var swagOffset = Note.halfWidth + modMgr.vPadding; // maybe vPadding can be a field variable?
		var reversePerc = getReverseValue(data, player);
		var shift = lerp(swagOffset, FlxG.height - swagOffset, reversePerc);
		
		var centerPercent = getCenterValue(player);		
		shift = lerp(shift, (FlxG.height * 0.5), centerPercent);
		
		pos.y = shift + lerp(visualDiff, -visualDiff, reversePerc);
		
		if ((obj.objType == NOTE))
		{
			var angleDir = (getSubmodValue("direction" + Std.string(data), player) + getSubmodValue("direction", player))* Math.PI / 180;
			var n:Note = cast obj;
			var x:Float = Note.halfWidth + field.field.getBaseX(data);
			pos.x = x + Math.cos(angleDir) * lerp(visualDiff, -visualDiff, reversePerc);
			pos.y = shift + Math.sin(angleDir) * lerp(visualDiff, -visualDiff, reversePerc);
			pos.y += n.typeOffsetY;
		}
		pos.x += obj.offsetX;
        pos.y += obj.offsetY;

		return pos;
	}

    override function getSubmods(){
        var subMods:Array<String> = ["cross", "split", "alternate", "centered", "unboundedReverse", "direction"];

		for (i in 0...PlayState.keyCount){
            subMods.push('reverse${i}');
			subMods.push('direction${i}');
        }

        return subMods;
    }

	override function modifyVert(beat:Float, vert:Vector3, idx:Int, obj:NoteObject, pos:Vector3, player:Int, data:Int, field:NoteField):Vector3
		{
			var angle:Float = getSubmodValue("direction" + Std.string(data), player) + getSubmodValue("direction", player) - 90;
	
			if((obj.objType == NOTE)){
				var note:Note = cast obj;
			if(note.isSustainNote){
			var radians = FlxAngle.TO_RAD;
	
			vert = VectorHelpers.rotateV3(vert, radians * angle, radians * angle, radians * 0);
				}
			}
			return vert;
		}
}
