import * as React from "react";
import * as Dialog from "@radix-ui/react-dialog";
import { useUiStore } from "@/lib/store";
import { useSubscribeMutation } from "@/lib/queries";
import { subscribeSchema } from "@/lib/schemas";
import { Button } from "./Button";

/**
 * covers: EARS-1 (subscribe with valid email), EARS-2 (reject invalid email)
 * — see specs/example-feature/spec.md.
 */
export function SubscribeDialog() {
  const isOpen = useUiStore((s) => s.isSubscribeDialogOpen);
  const open = useUiStore((s) => s.openSubscribeDialog);
  const close = useUiStore((s) => s.closeSubscribeDialog);
  const [email, setEmail] = React.useState("");
  const [error, setError] = React.useState<string | null>(null);
  const mutation = useSubscribeMutation();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const parsed = subscribeSchema.safeParse({ email });
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? "Invalid email");
      return;
    }
    setError(null);
    mutation.mutate(parsed.data, {
      onSuccess: () => {
        setEmail("");
        close();
      },
      onError: (err) => setError(err.message),
    });
  }

  return (
    <Dialog.Root open={isOpen} onOpenChange={(next) => (next ? open() : close())}>
      <Dialog.Trigger asChild>
        <Button onClick={open}>Subscribe</Button>
      </Dialog.Trigger>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 bg-black/40" />
        <Dialog.Content className="fixed left-1/2 top-1/2 w-80 -translate-x-1/2 -translate-y-1/2 rounded-lg bg-white p-6 shadow-lg">
          <Dialog.Title className="text-lg font-semibold">
            Subscribe to updates
          </Dialog.Title>
          <Dialog.Description className="mt-1 text-sm text-gray-600">
            We will only email you about new releases.
          </Dialog.Description>
          <form onSubmit={handleSubmit} className="mt-4 space-y-3" noValidate>
            <div>
              <label htmlFor="subscribe-email" className="text-sm font-medium">
                Email address
              </label>
              <input
                id="subscribe-email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                aria-invalid={error ? true : undefined}
                aria-describedby={error ? "subscribe-email-error" : undefined}
                className="mt-1 w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
              />
              {error ? (
                <p
                  id="subscribe-email-error"
                  role="alert"
                  className="mt-1 text-sm text-red-600"
                >
                  {error}
                </p>
              ) : null}
            </div>
            <div className="flex justify-end gap-2">
              <Dialog.Close asChild>
                <Button type="button" variant="ghost" size="sm">
                  Cancel
                </Button>
              </Dialog.Close>
              <Button type="submit" size="sm" disabled={mutation.isPending}>
                {mutation.isPending ? "Subscribing..." : "Confirm"}
              </Button>
            </div>
          </form>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
