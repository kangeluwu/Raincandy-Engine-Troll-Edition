package funkin.objects;
import openfl.Lib;
import lime.ui.Window;
import cpp.CppAPI;
import funkin.objects.FlxSpr;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.FlxBasic;
import lime.ui.Window;
import lime.ui.WindowAttributes;
typedef WindowSets = {
    var name:String;
    var instance:Dynamic;
    var hide:Bool;
    @:optional var spr:FlxSprite;
} 
class WindowsTarget extends FlxBasic
{
    public var targetWindow:Window;
    public var targetSprites:Array<FlxSpr> = [];
    public var sprs:Array<WindowSets> = [];
    public var currentAtt:WindowAttributes = {  
    title: "title",
    width: 1200, 
    height: 1200,
    x: 100,
    y: 100,
    borderless: true,
    alwaysOnTop: true
    };
    public function new(att:WindowAttributes = null){
        if (att != null)currentAtt = att;
        resetWindow();
        super();
    }
    public function resetWindow(){
            targetWindow = Lib.application.createWindow(currentAtt);
            CppAPI.setAlphaColor(0xFF010101);
            targetWindow.stage.color = 0xFF010101;
           
            Lib.application.window.onClose.add(close);
            targetWindow.onClose.add(() -> targetWindow = null);

            targetWindow.focus();
            Lib.application.window.focus();
            for (spr in sprs){
            var targetSprite = new FlxSpr(spr.instance, spr.name, spr.spr);
            targetSprite.offset.set(0, 0);
            targetWindow.stage.addChild(targetSprite);
            targetSprites.push(targetSprite);
                if (spr.hide){
                    if (Reflect.hasField(spr,'spr'))
                        spr.spr.visible = false;
                    else if (Reflect.getProperty(spr.instance, spr.name) != null){
                        Reflect.getProperty(spr.instance, spr.name).visible = false;
                    }
                }
            }
        }
        function close(){
           targetWindow?.close();
        }
    override public function destroy(){
        close();
    }
}