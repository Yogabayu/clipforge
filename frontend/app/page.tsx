"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import toast from "react-hot-toast";
import { createJob, deleteJobs, getJob, getJobs, renderSelection } from '../lib/apiClient';
import {
  DEFAULT_LANGUAGE,
  DEFAULT_MAX_DURATION,
  DEFAULT_MIN_DURATION,
  DEFAULT_MODEL,
  JOB_POLL_INTERVAL_MS,
  RECENT_LOG_LIMIT,
} from "../lib/constants";
import { isActiveJob } from "../lib/utils";
import type { ClipCandidate, ClipJob, ClipRange, CropMode, OutputAspect, OutputResolution } from '../types/clip.type';
import { AutoCutSection } from './_components/AutoCutSection';
import { ClipReviewSection } from './_components/ClipReviewSection';
import { ControlPanel } from "./_components/ControlPanel";
import { DeleteAllToast } from "./_components/DeleteAllToast";
import { HistorySection } from "./_components/HistorySection";
import { ResultsSection } from "./_components/ResultsSection";
import { SiteFooter } from "./_components/SiteFooter";
import { StatusPanel } from "./_components/StatusPanel";
import { Topbar } from "./_components/Topbar";

export default function HomePage() {
  const [url, setUrl] = useState("");
  const [cropMode, setCropMode] = useState<CropMode>("person");
  const [job, setJob] = useState<ClipJob | null>(null);
  const [editorJob, setEditorJob] = useState<ClipJob | null>(null);
  const [editorCandidate, setEditorCandidate] = useState<ClipCandidate | null>(null);
  const [jobs, setJobs] = useState<ClipJob[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");

  const activeJobId = job?.id;
  const isBusy = isActiveJob(job);
  const latestLogs = useMemo(() => job?.logs.slice(-RECENT_LOG_LIMIT) ?? [], [job]);

  const loadJobs = useCallback(async () => {
    setJobs(await getJobs());
  }, []);

  useEffect(() => {
    loadJobs().catch(() => undefined);
  }, [loadJobs]);

  useEffect(() => {
    if (!activeJobId) return;

    const interval = window.setInterval(async () => {
      const nextJob = await getJob(activeJobId);
      setJob(nextJob);

      if (nextJob.status === "completed" || nextJob.status === "failed") {
        loadJobs().catch(() => undefined);
      }
    }, JOB_POLL_INTERVAL_MS);

    return () => window.clearInterval(interval);
  }, [activeJobId, loadJobs]);

  useEffect(() => {
    if (job?.status === 'completed' && job.source_url && job.candidates.length) setEditorJob(job);
  }, [job]);

  const handleStartJob = useCallback(async () => {
    const trimmedUrl = url.trim();
    setError("");

    if (!trimmedUrl) {
      setError("Link YouTube tidak boleh kosong.");
      return;
    }

    setIsSubmitting(true);

    try {
      const nextJob = await toast.promise(
        createJob({
          url: trimmedUrl,
          min_duration: DEFAULT_MIN_DURATION,
          max_duration: DEFAULT_MAX_DURATION,
          model: DEFAULT_MODEL,
          language: DEFAULT_LANGUAGE,
          burn_subtitles: true,
          crop_mode: cropMode,
        }),
        {
          loading: "Mempersiapkan proses pemotongan...",
          success: "Proses pemotongan berhasil dimulai!",
          error: "Gagal memulai proses pemotongan",
        },
      );

      setJob(nextJob);
      setEditorJob(null);
      setEditorCandidate(null);
      await loadJobs();
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : "Gagal memulai proses.");
    } finally {
      setIsSubmitting(false);
    }
  }, [cropMode, loadJobs, url]);

  const handleDeleteAllConfirmed = useCallback(async () => {
    await toast.promise(deleteJobs(), {
      loading: "Menghapus riwayat...",
      success: "Seluruh riwayat berhasil dihapus!",
      error: "Gagal menghapus riwayat",
    });

    setJob(null);
    setEditorJob(null);
    setEditorCandidate(null);
    await loadJobs();
  }, [loadJobs]);

  const handleDeleteAll = useCallback(() => {
    toast((item) => <DeleteAllToast toastId={item.id} onConfirm={handleDeleteAllConfirmed} />, {
      duration: Infinity,
    });
  }, [handleDeleteAllConfirmed]);

  const handleRenderSelection = useCallback(async (
    ranges: ClipRange[],
    combine: boolean,
    outputAspect: OutputAspect,
    outputResolution: OutputResolution,
  ) => {
    if (!editorJob) return;
    const nextJob = await toast.promise(
      renderSelection(editorJob.id, ranges, combine, outputAspect, outputResolution),
      {
      loading: 'Menyiapkan bagian pilihan...',
      success: 'Render pilihan dimulai!',
      error: 'Gagal merender pilihan',
      },
    );
    setJob(nextJob);
    await loadJobs();
  }, [editorJob, loadJobs]);

  const handleSelectJob = useCallback((selectedJob: ClipJob) => {
    setJob(selectedJob);
    if (selectedJob.status === 'completed' && selectedJob.source_url) {
      setEditorJob(selectedJob);
      setEditorCandidate(null);
    }
  }, []);

  const handleSelectCandidate = useCallback((candidate: ClipCandidate) => {
    if (!editorJob?.source_url) return;
    setEditorCandidate(candidate);
    window.requestAnimationFrame(() => document.getElementById('video-editor')?.scrollIntoView({ behavior: 'smooth' }));
  }, [editorJob]);

  return (
    <main className="shell">
      <Topbar onRefresh={loadJobs} />

      <section className="workspace">
        <ControlPanel
          cropMode={cropMode}
          error={error}
          isBusy={isBusy}
          isSubmitting={isSubmitting}
          onCropModeChange={setCropMode}
          onStartJob={handleStartJob}
          onUrlChange={setUrl}
          url={url}
        />
        <StatusPanel job={job} latestLogs={latestLogs} />
      </section>

      <AutoCutSection
        candidates={editorJob?.candidates ?? []}
        onSelect={handleSelectCandidate}
        selectedIndex={editorCandidate?.index ?? null}
      />

      {editorJob ? (
        <div id='video-editor'>
          <ClipReviewSection
          exportDisabled={isBusy}
          initialRanges={editorCandidate ? [editorCandidate] : []}
          key={`${editorJob.id}-${editorCandidate?.index ?? 'empty'}`}
          onRender={handleRenderSelection}
          sourceUrl={editorJob.source_url}
          videoDuration={editorJob.video_duration}
          />
        </div>
      ) : null}

      <ResultsSection clips={job?.clips ?? []} />
      <HistorySection jobs={jobs} onDeleteAll={handleDeleteAll} onSelectJob={handleSelectJob} />
      <SiteFooter />
    </main>
  );
}
