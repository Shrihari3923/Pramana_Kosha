import emailjs from '@emailjs/browser';

const SERVICE_ID = import.meta.env.VITE_EMAILJS_SERVICE_ID as string;
const TEMPLATE_ID = import.meta.env.VITE_EMAILJS_TEMPLATE_ID as string;
const PUBLIC_KEY = import.meta.env.VITE_EMAILJS_PUBLIC_KEY as string;

const RECIPIENT = import.meta.env.VITE_OTP_RECIPIENT as string;
const RECIPIENT_2 = import.meta.env.VITE_OTP_RECIPIENT_2 as string;

emailjs.init(PUBLIC_KEY);

/** Returns a cryptographically-random 6-digit OTP string. */
export function generateOTP(): string {
  const arr = new Uint32Array(1);
  crypto.getRandomValues(arr);
  return String(arr[0] % 1_000_000).padStart(6, '0');
}

export async function sendOTP(params: {
  otp: string;
  userEmail: string;
  action?: string;
}): Promise<void> {
  const emailData = {
    otp_code: params.otp,
    user_email: params.userEmail,
    action: params.action || 'Secure Action',
  };

  // First email
  await emailjs.send(
    SERVICE_ID,
    TEMPLATE_ID,
    {
      ...emailData,
      to_email: RECIPIENT,
    },
    PUBLIC_KEY
  );

  // Second email
  if (RECIPIENT_2) {
    await emailjs.send(
      SERVICE_ID,
      TEMPLATE_ID,
      {
        ...emailData,
        to_email: RECIPIENT_2,
      },
      PUBLIC_KEY
    );
  }
}