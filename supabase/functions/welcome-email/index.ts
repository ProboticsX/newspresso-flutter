import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
// @deno-types="npm:@types/nodemailer@6.4.17"
import nodemailer from "npm:nodemailer@6.9.9";

serve(async (req) => {
  try {
    const payload = await req.json();
    const { first_name, email } = payload.record ?? {};

    if (!email) {
      return new Response("No email in record", { status: 400 });
    }

    const gmailUser = Deno.env.get("GMAIL_USER");
    const gmailAppPassword = Deno.env.get("GMAIL_APP_PASSWORD");

    if (!gmailUser || !gmailAppPassword) {
      return new Response("Missing Gmail credentials", { status: 500 });
    }

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: gmailUser,
        pass: gmailAppPassword,
      },
    });

    const name = first_name ?? "there";

    await transporter.sendMail({
      from: `"Newspresso" <${gmailUser}>`,
      to: email,
      subject: "Welcome to Newspresso! ☕",
      html: `
        <!DOCTYPE html>
        <html>
          <body style="font-family: sans-serif; background: #121212; color: #ffffff; padding: 32px;">
            <h2 style="color: #C8936A;">Welcome to Newspresso, ${name}! ☕</h2>
            <p>Thanks for signing up — we're really glad you're here.</p>
            <p>
              Newspresso is your daily dose of news, delivered in a format
              you'll actually enjoy. From quick shots to deep-dive podcasts,
              we've got you covered.
            </p>
            <p>Open the app and start exploring. If you ever have questions or
            feedback, just reply to this email — we read every one.</p>
            <br/>
            <p style="color: #C8936A; font-weight: bold;">— The Newspresso Team</p>
          </body>
        </html>
      `,
    });

    return new Response("Welcome email sent", { status: 200 });
  } catch (err) {
    console.error("Error sending welcome email:", err);
    return new Response(`Error: ${err}`, { status: 500 });
  }
});
