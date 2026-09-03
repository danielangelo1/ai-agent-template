import { createFileRoute } from "@tanstack/react-router";
import { Suspense, useState } from "react";
import { ArticleLikeButton } from "@/components/ArticleLikeButton";
import { SubscribeDialog } from "@/components/SubscribeDialog";
import { useSubscriberCount } from "@/lib/queries";

export const Route = createFileRoute("/")({
  component: HomePage,
});

function SubscriberCount() {
  const { data } = useSubscriberCount();
  return (
    <p className="text-gray-600" data-testid="subscriber-count">
      {data.count} people are already subscribed.
    </p>
  );
}

function HomePage() {
  const [articleLikes, setArticleLikes] = useState(128);

  return (
    <section aria-labelledby="home-heading" className="space-y-4">
      <h1 id="home-heading" className="text-2xl font-bold">
        frontend-agent-template
      </h1>

      <article className="space-y-3 rounded-lg border border-gray-200 p-4">
        <h2 className="text-xl font-semibold">
          Como construir uma interface útil sem fricção
        </h2>
        <p className="text-gray-700">
          Este artigo demonstra como pequenas interações de feedback ajudam o usuário a
          perceber valor imediatamente, sem complicar a navegação.
        </p>
        <ArticleLikeButton count={articleLikes} onLike={setArticleLikes} />
      </article>

      <Suspense fallback={<p>Loading subscriber count...</p>}>
        <SubscriberCount />
      </Suspense>
      <SubscribeDialog />
    </section>
  );
}
