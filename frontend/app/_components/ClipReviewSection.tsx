'use client';

import { Combine, Flag, Monitor, Play, Scissors, Smartphone, Trash2, Video } from 'lucide-react';
import { useMemo, useRef, useState } from 'react';
import { getOutputUrl } from '../../lib/apiClient';
import type { ClipRange, OutputAspect, OutputResolution } from '../../types/clip.type';

type ClipReviewSectionProps = {
  exportDisabled: boolean;
  initialRanges?: ClipRange[];
  sourceUrl: string | null;
  videoDuration: number | null;
  onRender: (
    ranges: ClipRange[],
    combine: boolean,
    outputAspect: OutputAspect,
    outputResolution: OutputResolution,
  ) => Promise<void>;
};

const MAX_SELECTIONS = 12;

const formatTime = (seconds: number) => {
  const value = Math.max(0, Math.floor(seconds));
  const hours = Math.floor(value / 3600);
  const minutes = Math.floor((value % 3600) / 60);
  const remainder = value % 60;
  return hours
    ? `${hours}:${minutes.toString().padStart(2, '0')}:${remainder.toString().padStart(2, '0')}`
    : `${minutes}:${remainder.toString().padStart(2, '0')}`;
};

const clamp = (value: number, minimum: number, maximum: number) => Math.max(minimum, Math.min(maximum, value));

export function ClipReviewSection({ exportDisabled, initialRanges = [], sourceUrl, videoDuration, onRender }: ClipReviewSectionProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [duration, setDuration] = useState(videoDuration ?? 0);
  const [playhead, setPlayhead] = useState(initialRanges[0]?.start ?? 0);
  const [ranges, setRanges] = useState<ClipRange[]>(initialRanges);
  const [combine, setCombine] = useState(false);
  const [outputAspect, setOutputAspect] = useState<OutputAspect>('portrait');
  const [outputResolution, setOutputResolution] = useState<OutputResolution>('1080p');
  const [draftStart, setDraftStart] = useState<number | null>(null);

  const selectedDuration = useMemo(
    () => ranges.reduce((total, range) => total + range.end - range.start, 0),
    [ranges],
  );

  if (!sourceUrl) return null;

  const seek = (seconds: number) => {
    const target = clamp(seconds, 0, duration);
    if (videoRef.current) videoRef.current.currentTime = target;
    setPlayhead(target);
  };

  const markRangeEnd = () => {
    if (draftStart === null || !duration || ranges.length >= MAX_SELECTIONS) return;
    const start = Math.min(draftStart, playhead);
    const end = Math.max(draftStart, playhead);
    if (end - start < 1) return;
    const nextIndex = Math.max(0, ...ranges.map((range) => range.index)) + 1;
    setRanges((current) => [...current, { index: nextIndex, start, end, title: `Bagian ${nextIndex}` }]);
    setDraftStart(null);
  };

  const updateRange = (index: number, field: 'start' | 'end', value: number) => {
    setRanges((current) => current.map((range) => {
      if (range.index !== index) return range;
      const start = field === 'start' ? clamp(value, 0, range.end - 1) : range.start;
      const end = field === 'end' ? clamp(value, range.start + 1, duration) : range.end;
      return { ...range, start, end };
    }));
  };

  const removeRange = (index: number) => setRanges((current) => current.filter((range) => range.index !== index));

  return (
    <section className='review fullVideoEditor' aria-labelledby='review-title'>
      <div className='sectionHeader'>
        <div>
          <h2 id='review-title'>Editor Video Lengkap</h2>
          <p className='sectionDescription'>Klik timeline atau putar video. Tandai posisi awal, pindah playhead, lalu tandai akhir.</p>
        </div>
        <span className='sectionBadge'>{formatTime(selectedDuration)} dipilih</span>
      </div>

      <div className='editorWorkspace'>
        <div className='editorPreview'>
          <video
            controls
            onLoadedMetadata={(event) => {
              setDuration(event.currentTarget.duration || videoDuration || 0);
              if (initialRanges[0]) event.currentTarget.currentTime = initialRanges[0].start;
            }}
            onTimeUpdate={(event) => setPlayhead(event.currentTarget.currentTime)}
            preload='metadata'
            ref={videoRef}
            src={getOutputUrl(sourceUrl)}
          />
          <div className='playheadReadout'>
            <span>Playhead</span>
            <strong>{formatTime(playhead)}</strong>
            <span>/ {formatTime(duration)}</span>
          </div>
        </div>

        <div className='timelinePanel'>
          <div
            className='masterTimeline'
            onClick={(event) => {
              const bounds = event.currentTarget.getBoundingClientRect();
              seek(((event.clientX - bounds.left) / bounds.width) * duration);
            }}
            role='slider'
            aria-label='Timeline video lengkap'
            aria-valuemax={duration}
            aria-valuemin={0}
            aria-valuenow={playhead}
            tabIndex={0}
          >
            <div className='discardTrack'>DIBUANG</div>
            {ranges.map((range) => (
              <button
                className='keepSegment'
                key={range.index}
                onClick={(event) => {
                  event.stopPropagation();
                  seek(range.start);
                }}
                style={{
                  left: `${(range.start / duration) * 100}%`,
                  width: `${((range.end - range.start) / duration) * 100}%`,
                }}
                title={`${range.title}: ${formatTime(range.start)}–${formatTime(range.end)}`}
                type='button'
              >
                SIMPAN {range.index}
              </button>
            ))}
            {draftStart !== null ? (
              <span
                className='draftSegment'
                style={{
                  left: `${(Math.min(draftStart, playhead) / duration) * 100}%`,
                  width: `${(Math.abs(playhead - draftStart) / duration) * 100}%`,
                }}
              />
            ) : null}
            <span className='timelinePlayhead' style={{ left: `${(playhead / duration) * 100}%` }} />
          </div>

          <div className='timelineScale'>
            <span>0:00</span>
            <span>{formatTime(duration / 2)}</span>
            <span>{formatTime(duration)}</span>
          </div>

          <div className='markRangeActions'>
            <button
              className={`secondaryButton markButton ${draftStart !== null ? 'isMarked' : ''}`}
              disabled={ranges.length >= MAX_SELECTIONS}
              onClick={() => setDraftStart(playhead)}
              type='button'
            >
              <Flag size={18} />
              Tandai Awal: {formatTime(draftStart ?? playhead)}
            </button>
            <button
              className='secondaryButton markButton'
              disabled={draftStart === null || Math.abs(playhead - draftStart) < 1}
              onClick={markRangeEnd}
              type='button'
            >
              <Scissors size={18} />
              Tandai Akhir: {formatTime(playhead)}
            </button>
            {draftStart !== null ? (
              <button className='cancelMarkButton' onClick={() => setDraftStart(null)} type='button'>Batal</button>
            ) : null}
          </div>
        </div>
      </div>

      <div className='selectionList'>
        {ranges.length ? ranges.map((range) => (
          <article className='selectionRow' key={range.index}>
            <button className='selectionPlay' onClick={() => seek(range.start)} title='Putar dari awal bagian' type='button'>
              <Play size={17} />
            </button>
            <strong>Bagian {range.index}</strong>
            <label>
              Mulai
              <input
                max={range.end - 1}
                min={0}
                onChange={(event) => updateRange(range.index, 'start', Number(event.target.value))}
                step='0.1'
                type='number'
                value={range.start.toFixed(1)}
              />
            </label>
            <label>
              Akhir
              <input
                max={duration}
                min={range.start + 1}
                onChange={(event) => updateRange(range.index, 'end', Number(event.target.value))}
                step='0.1'
                type='number'
                value={range.end.toFixed(1)}
              />
            </label>
            <span className='selectionDuration'>{formatTime(range.end - range.start)}</span>
            <button className='removeSelection' onClick={() => removeRange(range.index)} title='Buang tanda ini' type='button'>
              <Trash2 size={17} />
            </button>
          </article>
        )) : (
          <div className='selectionEmpty'>
            <Video size={28} />
            <p>Belum ada bagian disimpan. Area timeline saat ini akan dibuang.</p>
          </div>
        )}
      </div>

      <div className='editorFooter'>
        <div className='exportSettings'>
          <div>
            <span className='exportSettingLabel'>Susunan hasil</span>
            <div className='exportMode' aria-label='Mode hasil ekspor'>
              <button className={!combine ? 'active' : ''} onClick={() => setCombine(false)} type='button'>Terpisah</button>
              <button className={combine ? 'active' : ''} onClick={() => setCombine(true)} type='button'><Combine size={16} /> Gabung</button>
            </div>
          </div>
          <div>
            <span className='exportSettingLabel'>Format video</span>
            <div className='exportMode' aria-label='Format video hasil'>
              <button className={outputAspect === 'portrait' ? 'active' : ''} onClick={() => setOutputAspect('portrait')} type='button'><Smartphone size={16} /> Portrait 9:16</button>
              <button className={outputAspect === 'landscape' ? 'active' : ''} onClick={() => setOutputAspect('landscape')} type='button'><Monitor size={16} /> Landscape 16:9</button>
            </div>
          </div>
          <div>
            <span className='exportSettingLabel'>Resolusi</span>
            <div className='exportMode' aria-label='Resolusi video hasil'>
              {(['720p', '1080p', '1440p'] as OutputResolution[]).map((resolution) => (
                <button
                  className={outputResolution === resolution ? 'active' : ''}
                  key={resolution}
                  onClick={() => setOutputResolution(resolution)}
                  type='button'
                >
                  {resolution}
                </button>
              ))}
            </div>
          </div>
        </div>
        <button
          className='primary exportButton'
          disabled={exportDisabled || !ranges.length}
          onClick={() => onRender(ranges, combine, outputAspect, outputResolution)}
          type='button'
        >
          <Scissors size={18} />
          Ekspor Bagian ({ranges.length})
        </button>
      </div>
    </section>
  );
}
