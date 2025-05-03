package funkin.objects;

import flixel.FlxCamera;
import flixel.math.FlxMath;
class FunkinCamera extends FlxCamera
{
    public var defaultCamZoom:Float = 1;
    public var zoomScaleX:Float = 1;
    public var zoomScaleY:Float = 1;
    public var cameraSpeed:Float = 1;
    public var useLerp:Bool = false;
    override function set_zoom(Zoom:Float):Float
        {
            zoom = (Zoom == 0) ? defaultCamZoom : Zoom;
            setScale(zoom * zoomScaleX, zoom * zoomScaleY);
            return zoom;
        }
        override public function update(elapsed:Float):Void
            {
                if (useLerp){
                var lerpVal:Float = Math.exp(-elapsed * 2.4 * cameraSpeed);
                zoom = FlxMath.lerp(
                    defaultCamZoom,
                    zoom,
                    lerpVal
                );
                }
                super.update(elapsed);
            }
}
