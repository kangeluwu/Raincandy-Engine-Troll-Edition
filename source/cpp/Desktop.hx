package cpp;

@:headerCode('
  #include <shobjidl_core.h>
  #include <windows.h>
  #include <winuser.h>
  #include <combaseapi.h>

  #pragma comment(lib, "user32.lib")
  #pragma comment(lib, "kernel32.lib")
  #pragma comment(lib, "ole32.lib")
')
class Desktop
{
  @:functionCode("
    HRESULT hr = ::CoInitialize(nullptr);
    IDesktopWallpaper* pDesktopWallpaper = nullptr;
    hr = ::CoCreateInstance(__uuidof(DesktopWallpaper), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&pDesktopWallpaper));
    if (!FAILED(hr))
      pDesktopWallpaper->Enable(value);
  ")
  static function _enable(value:Int) {}
  @:functionCode("
    COLORREF col = 0;
    HRESULT hr = ::CoInitialize(nullptr);
    IDesktopWallpaper* pDesktopWallpaper = nullptr;
    hr = ::CoCreateInstance(__uuidof(DesktopWallpaper), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&pDesktopWallpaper));
    if (!FAILED(hr))
      pDesktopWallpaper->GetBackgroundColor(&col);
    return col;
  ")
  static function _getBGColor():Int return 0;
  @:functionCode("
    LPWSTR name;
    HRESULT hr = ::CoInitialize(nullptr);
    IDesktopWallpaper* pDesktopWallpaper = nullptr;
    hr = ::CoCreateInstance(__uuidof(DesktopWallpaper), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&pDesktopWallpaper));
    if (!FAILED(hr))
      pDesktopWallpaper->GetMonitorDevicePathAt(index, &name);
    return (const char*)name;
  ")
  static function _getMonitorDevice(index:Int):String return null;
  @:functionCode("
    UINT count;
    HRESULT hr = ::CoInitialize(nullptr);
    IDesktopWallpaper* pDesktopWallpaper = nullptr;
    hr = ::CoCreateInstance(__uuidof(DesktopWallpaper), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&pDesktopWallpaper));
    if (!FAILED(hr))
      pDesktopWallpaper->GetMonitorDevicePathCount(&count);
    return count;
  ")
  static function _getMonitorCount():Int return 1;
  @:functionCode('
    HRESULT hr = ::CoInitialize(nullptr);
    IDesktopWallpaper* pDesktopWallpaper = nullptr;
    hr = ::CoCreateInstance(__uuidof(DesktopWallpaper), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&pDesktopWallpaper));
    if (!FAILED(hr))
      pDesktopWallpaper->SetBackgroundColor(RGB(r,g,b));
  ')
  static function _setBGColor(r:Int, g:Int, b:Int) {}
  @:functionCode('
    HRESULT hr = ::CoInitialize(nullptr);
    IDesktopWallpaper* pDesktopWallpaper = nullptr;
    hr = ::CoCreateInstance(__uuidof(DesktopWallpaper), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&pDesktopWallpaper));
    if (!FAILED(hr))
      pDesktopWallpaper->SetWallpaper((LPCWSTR)name,(LPWSTR)data);
  ')
  static function _setWallpaper(name:ConstCharStar, data:ConstCharStar) {}
  @:functionCode("
    LPWSTR wallpaper;
    HRESULT hr = ::CoInitialize(nullptr);
    IDesktopWallpaper* pDesktopWallpaper = nullptr;
    hr = ::CoCreateInstance(__uuidof(DesktopWallpaper), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&pDesktopWallpaper));
    if (!FAILED(hr))
      pDesktopWallpaper->GetWallpaper((LPCWSTR)device, &wallpaper);
    return (const char*)wallpaper;
  ")
  static function _getWallpaper(device:ConstCharStar):String return null;
  @:functionCode("
    RECT size;
    HRESULT hr = ::CoInitialize(nullptr);
    IDesktopWallpaper* pDesktopWallpaper = nullptr;
    hr = ::CoCreateInstance(__uuidof(DesktopWallpaper), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&pDesktopWallpaper));
    if (!FAILED(hr))
      pDesktopWallpaper->GetMonitorRECT((LPCWSTR)device, &size);
    return size.left + size.right;
  ")
  static function _getMonitorW(device:ConstCharStar):Float return 0;
  @:functionCode("
    RECT size;
    HRESULT hr = ::CoInitialize(nullptr);
    IDesktopWallpaper* pDesktopWallpaper = nullptr;
    hr = ::CoCreateInstance(__uuidof(DesktopWallpaper), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&pDesktopWallpaper));
    if (!FAILED(hr))
      pDesktopWallpaper->GetMonitorRECT((LPCWSTR)device, &size);
    return size.top + size.bottom;
  ")
  static function _getMonitorH(device:ConstCharStar):Float return 0;

  public static function enable(value:Bool) _enable(value ? 1 : 0);
  public static function getBackgroundColor():Int return _getBGColor();
  public static function getMonitorByID(index:Int) return _getMonitorDevice(index);
  public static function getMonitorCount() return _getMonitorCount();
  public static function setBackgroundColor(r:Int, g:Int, b:Int) _setBGColor(r,g,b);
  public static function setWallpaper(device:ConstCharStar, image:ConstCharStar) _setWallpaper(device, image);
  public static function getWallpaper(device:ConstCharStar) return _getWallpaper(device);
  public static function getMonitorWidth(device:ConstCharStar) return _getMonitorW(device);
  public static function getMonitorHeight(device:ConstCharStar) return _getMonitorH(device);
}