// config.js
export const config = {
  server: {
    port: process.env.PORT     ?? 8080,
    env:  process.env.NODE_ENV ?? 'development',
  },

  appInsights: {
    connectionString: process.env.APPLICATIONINSIGHTS_CONNECTION_STRING,
  },

  storage: {
    accountName:   process.env.STORAGE_ACCOUNT_NAME,
    containerName: process.env.BLOB_CONTAINER_NAME,
  },

  identity: {
    uamiClientId:  process.env.UAMI_CLIENT_ID,
    principalId:   process.env.UAMI_PRINCIPAL_ID,
  },
}