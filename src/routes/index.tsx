import { createFileRoute } from "@tanstack/react-router";
import { Suspense } from "react";
import { useSubscriberCount } from "@/lib/queries";
import { SubscribeDialog } from "@/components/SubscribeDialog";

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
  return (
    <section aria-labelledby="home-heading" className="space-y-4">
      <h1 id="home-heading" className="text-2xl font-bold">
        frontend-agent-template
      </h1>
      <Suspense fallback={<p>Loading subscriber count...</p>}>
        <SubscriberCount />
      </Suspense>
      <SubscribeDialog />
    </section>
  );
}
