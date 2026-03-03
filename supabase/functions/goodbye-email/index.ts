import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
// @deno-types="npm:@types/nodemailer@6.4.17"
import nodemailer from "npm:nodemailer@6.9.9";

serve(async (req) => {
  try {
    const payload = await req.json();

    // DELETE webhooks send the deleted row in old_record
    const { first_name, email } = payload.old_record ?? {};

    if (!email) {
      return new Response("No email in old_record", { status: 400 });
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
      subject: "Sorry to see you go ☕",
      html: `
        <!DOCTYPE html>
        <html>
          <body style="font-family: sans-serif; background: #121212; color: #ffffff; padding: 32px;">
            <h2 style="color: #C8936A;">We're sorry to see you go, ${name}.</h2>
            <p>Your Newspresso account has been successfully deleted. All your data has been removed from our systems.</p>
            <p>
              We'd love to know what we could have done better. If you have a moment,
              hit reply and let us know — every piece of feedback helps us improve.
            </p>
            <p>
              If you ever change your mind, you're always welcome back. Just sign up
              again and we'll be here with a fresh cup. ☕
            </p>
            <br/>
            <p style="color: #C8936A; font-weight: bold;">— The Newspresso Team</p>
          </body>
        </html>
      `,
    });

    return new Response("Goodbye email sent", { status: 200 });
  } catch (err) {
    console.error("Error sending goodbye email:", err);
    return new Response(`Error: ${err}`, { status: 500 });
  }
});
