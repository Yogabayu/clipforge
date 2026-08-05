import { Loader2, Play, Scissors } from "lucide-react";
import type { CropMode } from "../../types/clip.type";

type ControlPanelProps = {
  cropMode: CropMode;
  error: string;
  isBusy: boolean;
  isSubmitting: boolean;
  maxDuration: number;
  minDuration: number;
  onCropModeChange: (mode: CropMode) => void;
  onMaxDurationChange: (value: number) => void;
  onMinDurationChange: (value: number) => void;
  onStartJob: () => void;
  onUrlChange: (value: string) => void;
  url: string;
};

export function ControlPanel({
  cropMode,
  error,
  isBusy,
  isSubmitting,
  maxDuration,
  minDuration,
  onCropModeChange,
  onMaxDurationChange,
  onMinDurationChange,
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

      <div className="gridFields">
        <label className="field">
          <span>Durasi Minimum</span>
          <input
            min={5}
            max={600}
            type="number"
            value={minDuration}
            onChange={(event) => onMinDurationChange(Number(event.target.value))}
          />
        </label>
        <label className="field">
          <span>Durasi Maksimum</span>
          <input
            min={10}
            max={600}
            type="number"
            value={maxDuration}
            onChange={(event) => onMaxDurationChange(Number(event.target.value))}
          />
        </label>
      </div>

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
        </div>
        <p className="field-help">
          {cropMode === "center"
            ? "Rasio video dipertahankan; ruang atas dan bawah diisi abu-abu."
            : "Video di-crop vertikal mengikuti posisi orang yang terdeteksi."}
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
