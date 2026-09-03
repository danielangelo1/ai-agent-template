import { z } from "zod";

export const subscribeSchema = z.object({
  email: z.string().email("Enter a valid email address"),
});

export type SubscribeInput = z.infer<typeof subscribeSchema>;

export const subscriberCountSchema = z.object({
  count: z.number().int().nonnegative(),
});

export type SubscriberCount = z.infer<typeof subscriberCountSchema>;
