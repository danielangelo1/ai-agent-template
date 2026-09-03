import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/about")({
  component: AboutPage,
});

function AboutPage() {
  return (
    <section aria-labelledby="about-heading" className="space-y-2">
      <h1 id="about-heading" className="text-2xl font-bold">
        About
      </h1>
      <p className="text-gray-600">
        This is the minimal example app that proves the template's harness (specs, agents,
        hooks, verify.sh) end to end. See specs/example-feature/.
      </p>
    </section>
  );
}
