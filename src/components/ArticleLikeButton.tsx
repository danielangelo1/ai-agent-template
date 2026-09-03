import { useState } from "react";
import { Button } from "@/components/Button";

interface ArticleLikeButtonProps {
  count?: number;
  supportsLikes?: boolean;
  onLike?: (nextCount: number) => void;
}

export function ArticleLikeButton({
  count,
  supportsLikes = true,
  onLike,
}: ArticleLikeButtonProps) {
  const initialCount = typeof count === "number" && Number.isFinite(count) ? count : 0;
  const [localCount, setLocalCount] = useState(initialCount);
  const displayedCount = onLike ? initialCount : localCount;

  if (!supportsLikes) {
    return null;
  }

  const handleClick = () => {
    const nextCount = displayedCount + 1;
    setLocalCount(nextCount);
    onLike?.(nextCount);
  };

  return (
    <div className="inline-flex items-center gap-3 rounded-md border border-brand-200 bg-brand-50 px-3 py-2">
      <Button type="button" variant="secondary" onClick={handleClick} aria-label="Curtir">
        Curtir
      </Button>
      <span aria-live="polite" className="text-sm font-medium text-brand-700">
        {displayedCount}
      </span>
    </div>
  );
}
