import { Coffee, Heart } from "lucide-react";

export function SiteFooter() {
  return (
    <footer className="siteFooter">
      <p>
        Open-source project by{" "}
        <a href="https://yogabayuap.com/" target="_blank" rel="noreferrer">
          Yoga Bayu A.P
        </a>
        <Heart size={14} aria-hidden="true" />
        forked from{" "}
        <a
          href="https://github.com/mallexibra-dev/clipforge"
          target="_blank"
          rel="noreferrer"
        >
          ClipForge
        </a>
      </p>
      <a
        className="donationLink"
        href="https://saweria.co/yogabayuap"
        target="_blank"
        rel="noreferrer"
      >
        <Coffee size={16} aria-hidden="true" />
        Buy me a coffee
      </a>
    </footer>
  );
}
