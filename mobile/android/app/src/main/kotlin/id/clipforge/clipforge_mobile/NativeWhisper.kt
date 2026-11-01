package id.clipforge.clipforge_mobile

object NativeWhisper {
    init { System.loadLibrary("clipforge_whisper") }
    external fun transcribe(model: String, pcm: String, language: String): Array<String>
    external fun progress(): Int
    external fun cancel()
}
