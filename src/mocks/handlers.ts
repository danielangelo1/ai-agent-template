import { http, HttpResponse } from "msw";

let subscriberCount = 128;

export const handlers = [
  http.get("/api/subscribers", () => {
    return HttpResponse.json({ count: subscriberCount });
  }),

  http.post("/api/subscribers", async ({ request }) => {
    const body = (await request.json()) as { email?: string };

    if (!body.email || !body.email.includes("@")) {
      return HttpResponse.json({ message: "Invalid email address" }, { status: 400 });
    }

    subscriberCount += 1;
    return HttpResponse.json({ count: subscriberCount }, { status: 201 });
  }),
];

/** Test-only: reset mutable mock state between test files. */
export function resetSubscriberCount(value = 128) {
  subscriberCount = value;
}
