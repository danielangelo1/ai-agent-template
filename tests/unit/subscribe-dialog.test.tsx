import { describe, expect, it } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { SubscribeDialog } from "@/components/SubscribeDialog";
import { renderWithProviders } from "./test-utils";

describe("SubscribeDialog", () => {
  // covers: EARS-1 — see specs/example-feature/spec.md
  it("subscribes with a valid email and closes the dialog", async () => {
    const user = userEvent.setup();
    renderWithProviders(<SubscribeDialog />);

    await user.click(screen.getByRole("button", { name: /subscribe/i }));
    await user.type(screen.getByLabelText(/email address/i), "person@example.com");
    await user.click(screen.getByRole("button", { name: /confirm/i }));

    await waitFor(() => {
      expect(
        screen.queryByRole("dialog", { name: /subscribe to updates/i }),
      ).not.toBeInTheDocument();
    });
  });

  // covers: EARS-2 — see specs/example-feature/spec.md
  it("rejects an invalid email without calling the API", async () => {
    const user = userEvent.setup();
    renderWithProviders(<SubscribeDialog />);

    await user.click(screen.getByRole("button", { name: /subscribe/i }));
    await user.type(screen.getByLabelText(/email address/i), "not-an-email");
    await user.click(screen.getByRole("button", { name: /confirm/i }));

    expect(await screen.findByRole("alert")).toHaveTextContent(/valid email/i);
    expect(
      screen.getByRole("dialog", { name: /subscribe to updates/i }),
    ).toBeInTheDocument();
  });
});
