export type JobStatus = "queued" | "running" | "completed" | "failed";
export type CropMode = 'center' | 'person' | 'clip';
export type OutputAspect = 'portrait' | 'landscape';
export type OutputResolution = '720p' | '1080p' | '1440p';

export type ClipFile = {
  name: string;
  url: string;
  size_bytes: number;
};

export type ClipCandidate = {
  index: number;
  start: number;
  end: number;
  duration: number;
  score: number;
  title: string;
  reason: string;
  text: string;
  score_breakdown?: Record<string, number>;
};

export type ClipJob = {
  id: string;
  status: JobStatus;
  created_at: string;
  updated_at: string;
  logs: string[];
  clips: ClipFile[];
  candidates: ClipCandidate[];
  source_url: string | null;
  video_duration: number | null;
  error: string | null;
  request: {
    url: string;
    top: number | null;
    min_duration: number;
    max_duration: number;
    model: string;
    language: string;
    analyze_seconds: number | null;
    burn_subtitles: boolean;
    crop_mode: CropMode;
  };
};

export type ClipRange = Pick<ClipCandidate, 'index' | 'start' | 'end' | 'title'>;

export type CreateClipJobInput = {
  url: string;
  top?: number;
  min_duration: number;
  max_duration: number;
  model: string;
  language: string;
  analyze_seconds?: number | null;
  burn_subtitles: boolean;
  crop_mode: CropMode;
};
