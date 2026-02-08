# Email Verification Backend Integration Guide

## Overview

This guide explains how to integrate Resend email verification into your backend API. The Flutter app is already configured to work with the following endpoints.

## Required Backend Endpoints

### 1. Update `/auth/signup` Endpoint

The signup endpoint should:
- Create the user account
- Generate a 6-digit verification code (or token)
- Send verification email using Resend
- Return a token (user can be logged in but email not verified yet)
- Store `emailVerified: false` in user record

**Expected Response:**
```json
{
  "token": "jwt_token_here"
}
```

### 2. New Endpoint: `POST /auth/verify-email`

**Request Body:**
```json
{
  "token": "123456"
}
```

**Response:**
- 200: Email verified successfully
- 400: Invalid or expired token

**Implementation:**
- Verify the token matches the one sent to user's email
- Update user record: `emailVerified: true`
- Optionally invalidate the verification token

### 3. New Endpoint: `POST /auth/resend-verification`

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
- 200: Verification email sent successfully

**Implementation:**
- Get user from JWT token
- Generate new 6-digit verification code
- Send new verification email using Resend
- Update stored verification code

### 4. Update `/me` Endpoint

Include `emailVerified` field in the response:
```json
{
  "id": "...",
  "username": "...",
  "email": "...",
  "emailVerified": true,
  ...
}
```

## Resend Integration (Node.js/Backend)

### Install Resend

```bash
npm install resend
```

### Backend Implementation Example

```javascript
import { Resend } from 'resend';

const resend = new Resend('re_io587wU8_PM6aHpQwFTFgMjp97716qPeV');

// Generate 6-digit verification code
function generateVerificationCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Send verification email
async function sendVerificationEmail(email, code) {
  try {
    await resend.emails.send({
      from: 'Yummy <onboarding@resend.dev>', // Update with your verified domain
      to: email,
      subject: 'Verify Your Email - Yummy',
      html: `
        <h2>Welcome to Yummy!</h2>
        <p>Please verify your email address by entering the following code in the app:</p>
        <h1 style="font-size: 32px; letter-spacing: 8px; text-align: center; margin: 20px 0;">
          ${code}
        </h1>
        <p>This code will expire in 24 hours.</p>
        <p>If you didn't create an account, please ignore this email.</p>
      `,
    });
    return true;
  } catch (error) {
    console.error('Failed to send verification email:', error);
    throw error;
  }
}

// In your signup route
app.post('/auth/signup', async (req, res) => {
  // ... create user logic ...
  
  // Generate verification code
  const verificationCode = generateVerificationCode();
  
  // Store code in database (with expiration, e.g., 24 hours)
  await db.users.update(userId, {
    emailVerified: false,
    verificationCode: verificationCode,
    verificationCodeExpires: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours
  });
  
  // Send verification email
  await sendVerificationEmail(user.email, verificationCode);
  
  // Return token
  const token = generateJWT(user);
  res.json({ token });
});

// Verify email endpoint
app.post('/auth/verify-email', async (req, res) => {
  const { token: code } = req.body;
  const authToken = req.headers.authorization?.replace('Bearer ', '');
  
  if (!authToken) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  const user = await getUserFromToken(authToken);
  
  if (!user || user.verificationCode !== code) {
    return res.status(400).json({ error: 'Invalid verification code' });
  }
  
  if (new Date() > user.verificationCodeExpires) {
    return res.status(400).json({ error: 'Verification code expired' });
  }
  
  // Update user
  await db.users.update(user.id, {
    emailVerified: true,
    verificationCode: null,
    verificationCodeExpires: null
  });
  
  res.json({ success: true });
});

// Resend verification endpoint
app.post('/auth/resend-verification', async (req, res) => {
  const authToken = req.headers.authorization?.replace('Bearer ', '');
  
  if (!authToken) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  const user = await getUserFromToken(authToken);
  
  if (user.emailVerified) {
    return res.status(400).json({ error: 'Email already verified' });
  }
  
  // Generate new code
  const verificationCode = generateVerificationCode();
  
  await db.users.update(user.id, {
    verificationCode: verificationCode,
    verificationCodeExpires: new Date(Date.now() + 24 * 60 * 60 * 1000)
  });
  
  await sendVerificationEmail(user.email, verificationCode);
  
  res.json({ success: true });
});
```

## Database Schema Updates

Add these fields to your users table:
- `emailVerified` (boolean, default: false)
- `verificationCode` (string, nullable)
- `verificationCodeExpires` (datetime, nullable)

## Important Notes

1. **Resend API Key**: The API key `re_io587wU8_PM6aHpQwFTFgMjp97716qPeV` should be stored as an environment variable, not hardcoded.

2. **Email Domain**: Update the `from` field to use your verified domain in Resend. The current `onboarding@resend.dev` is for testing.

3. **Code Expiration**: Verification codes should expire (recommended: 24 hours).

4. **Security**: 
   - Rate limit verification attempts
   - Rate limit resend requests
   - Invalidate old codes when new ones are generated

5. **Email Template**: Customize the HTML email template to match your app's branding.

## Testing

1. Test signup flow - should receive email
2. Test verification with correct code
3. Test verification with incorrect code
4. Test verification with expired code
5. Test resend functionality
6. Test that verified users can't request resend

## Flutter App Integration

The Flutter app is already configured to:
- Navigate to verification screen after signup
- Allow users to enter verification code
- Resend verification emails
- Handle verification success/failure

No additional Flutter changes needed once backend is implemented.
