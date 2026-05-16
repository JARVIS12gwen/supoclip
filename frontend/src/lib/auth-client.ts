import { createAuthClient } from "better-auth/react";

export const authClient = createAuthClient();

export const {
  signIn,
  signOut,
  signUp,
} = authClient;

export const useSession = () => ({
  data: {
    user: {
      id: "anonymous-user",
      name: "Anonymous User",
      email: "anonymous@example.com",
      image: null
    }
  },
  isPending: false,
  error: null,
  refetch: () => Promise.resolve()
});

