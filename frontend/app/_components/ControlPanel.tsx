import { Loader2, Play, Scissors } from "lucide-react";
import type { CropMode } from "../../types/clip.type";

type ControlPanelProps = {
  cropMode: CropMode;
  error: string;
  isBusy: boolean;
  isSubmitting: boolean;
  onCropModeChange: (mode: CropMode) => void;
  onStartJob: () => void;
  onUrlChange: (value: string) => void;
  url: string;
};

export function ControlPanel({
  cropMode,
  error,
  isBusy,
  isSubmitting,
  onCropModeChange,
  onStartJob,
  onUrlChange,
  url,
}: ControlPanelProps) {
  const isStartDisabled = isSubmitting || isBusy || !url.trim();
  const isProcessing = isSubmitting || isBusy;

  return (
    <section className="panel controlPanel">
      <div className="panelHeader">
        <Scissors size={20} />
        <h2>Potong Video YouTube</h2>
      </div>

      <label className="field wide">
        <span>Link Video YouTube</span>
        <input
          value={url}
          onChange={(event) => onUrlChange(event.target.value)}
          placeholder="https://www.youtube.com/watch?v=..."
          required
        />
        <p className="field-help">Pastikan video memiliki percakapan yang jelas untuk hasil transkripsi terbaik.</p>
      </label>

      <div className="segmentedField">
        <span>Mode Crop</span>
        <div className="segmentedControl" role="group" aria-label="Mode crop video">
          <button
            className={cropMode === "center" ? "active" : ""}
            type="button"
            onClick={() => onCropModeChange("center")}
          >
            Fit Landscape
          </button>
          <button
            className={cropMode === "person" ? "active" : ""}
            type="button"
            onClick={() => onCropModeChange("person")}
          >
            Follow Person
          </button>
          <button
            className={cropMode === "clip" ? "active" : ""}
            type="button"
            onClick={() => onCropModeChange("clip")}
          >
            Clip
          </button>
        </div>
        <p className="field-help">
          {cropMode === "center"
            ? "Rasio video dipertahankan; ruang atas dan bawah diisi abu-abu."
            : cropMode === "person"
              ? "Video di-crop vertikal mengikuti posisi orang yang terdeteksi."
              : "Gabungkan maksimal 5 hook terbaik menjadi satu video; nomor segmen tampil di kiri."}
        </p>
      </div>

      {error ? <p className="error">{error}</p> : null}

      <button className="primary" type="button" disabled={isStartDisabled} onClick={onStartJob}>
        {isProcessing ? <Loader2 className="spin" size={18} /> : <Play size={18} />}
        {isProcessing ? "Sedang Memproses..." : "Mulai Potong Video"}
      </button>
    </section>
  );
}
