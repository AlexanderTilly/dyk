package app.passim

import com.ryanheise.audioservice.AudioServiceActivity

// Extends AudioServiceActivity (instead of FlutterActivity) so
// just_audio_background can attach its media session — required, otherwise
// the app hangs on a black screen at startup.
class MainActivity : AudioServiceActivity()
