import { useMutation, useQueryClient, useSuspenseQuery } from "@tanstack/react-query";
import { subscribeSchema, subscriberCountSchema, type SubscribeInput } from "./schemas";

const SUBSCRIBERS_KEY = ["subscribers", "count"] as const;

async function fetchSubscriberCount() {
  const res = await fetch("/api/subscribers");
  if (!res.ok) throw new Error("Failed to load subscriber count");
  return subscriberCountSchema.parse(await res.json());
}

export function useSubscriberCount() {
  return useSuspenseQuery({
    queryKey: SUBSCRIBERS_KEY,
    queryFn: fetchSubscriberCount,
  });
}

async function postSubscribe(input: SubscribeInput) {
  const res = await fetch("/api/subscribers", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });

  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string } | null;
    throw new Error(body?.message ?? "Subscription failed");
  }

  return subscriberCountSchema.parse(await res.json());
}

export function useSubscribeMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: unknown) => postSubscribe(subscribeSchema.parse(input)),
    onSuccess: (data) => {
      queryClient.setQueryData(SUBSCRIBERS_KEY, data);
    },
  });
}
