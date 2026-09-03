import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Button } from "@/components/Button";

describe("Button", () => {
  it("renders accessible text and responds to click", async () => {
    const onClick = vi.fn();
    const user = userEvent.setup();
    render(<Button onClick={onClick}>Save changes</Button>);

    const button = screen.getByRole("button", { name: "Save changes" });
    await user.click(button);

    expect(onClick).toHaveBeenCalledOnce();
  });

  it("is disabled and inert when the disabled prop is set", () => {
    render(<Button disabled>Save changes</Button>);
    expect(screen.getByRole("button", { name: "Save changes" })).toBeDisabled();
  });
});
