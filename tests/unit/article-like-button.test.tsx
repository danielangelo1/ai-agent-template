import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { ArticleLikeButton } from "@/components/ArticleLikeButton";

describe("ArticleLikeButton", () => {
  it("renders a safe default of zero when no count exists yet", () => {
    render(<ArticleLikeButton count={undefined} />);

    expect(screen.getByRole("button", { name: /curtir/i })).toBeInTheDocument();
    expect(screen.getByText("0")).toBeInTheDocument();
  });

  it("increments the visible count when clicked", async () => {
    const user = userEvent.setup();
    render(<ArticleLikeButton count={4} />);

    await user.click(screen.getByRole("button", { name: /curtir/i }));

    expect(screen.getByText("5")).toBeInTheDocument();
  });

  it("hides the control when likes are not supported on the page", () => {
    render(<ArticleLikeButton count={12} supportsLikes={false} />);

    expect(screen.queryByRole("button", { name: /curtir/i })).not.toBeInTheDocument();
  });
});
