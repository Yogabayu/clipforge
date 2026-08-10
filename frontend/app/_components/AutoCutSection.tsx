import { Check, PencilLine, Scissors } from 'lucide-react';
import type { ClipCandidate } from '../../types/clip.type';

type AutoCutSectionProps = {
  candidates: ClipCandidate[];
  selectedIndex: number | null;
  onSelect: (candidate: ClipCandidate) => void;
};

const formatTime = (seconds: number) => {
  const value = Math.max(0, Math.floor(seconds));
  const minutes = Math.floor(value / 60);
  const remainder = value % 60;
  return `${minutes}:${remainder.toString().padStart(2, '0')}`;
};

export function AutoCutSection({ candidates, selectedIndex, onSelect }: AutoCutSectionProps) {
  if (!candidates.length) return null;

  return (
    <section className='review autoCutSection' aria-labelledby='auto-cut-title'>
      <div className='sectionHeader'>
        <div>
          <h2 id='auto-cut-title'>Auto Cut</h2>
          <p className='sectionDescription'>Pilih rekomendasi, lalu atur ulang titik mulai dan akhir di Editor Video Lengkap.</p>
        </div>
        <span className='sectionBadge'>{candidates.length} rekomendasi</span>
      </div>
      <div className='candidateList'>
        {candidates.map((candidate) => {
          const selected = candidate.index === selectedIndex;
          return (
            <article className={`candidateCard ${selected ? 'isSelected' : ''}`} key={candidate.index}>
              <div className='candidateHeading'>
                <span className='autoCutIndex'><Scissors size={15} /> Auto Cut {candidate.index}</span>
                {selected ? <span className='autoCutSelected'><Check size={14} /> Dipilih</span> : null}
              </div>
              <div className='candidateMeta'>
                <span>{formatTime(candidate.start)}–{formatTime(candidate.end)}</span>
                <span>{Math.round(candidate.duration)} detik</span>
                <span>Skor {candidate.score}</span>
              </div>
              <h3>{candidate.title}</h3>
              <p className='candidateReason'>{candidate.reason}</p>
              {candidate.text ? <p className='candidateText'>{candidate.text}</p> : null}
              <button className='secondaryButton autoCutEditButton' onClick={() => onSelect(candidate)} type='button'>
                <PencilLine size={16} />
                {selected ? 'Atur Lagi di Editor' : 'Pilih & Atur di Editor'}
              </button>
            </article>
          );
        })}
      </div>
    </section>
  );
}
