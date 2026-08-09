# k8s/ — kijani-project namespace

## Secret recovery

`kk-payments-secrets` is created imperatively and is **not** committed to git
(see `kk-payments-secrets.yaml.example` for the key structure only).

If the cluster is deleted and recreated, this Secret must be recreated by hand
before `kk-payments` will start successfully.

**Secret name:** `kk-payments-secrets`

**Expected keys:**
- `DB_PASSWORD`
- `STRIPE_API_KEY`
- `JWT_SECRET`

**Values must be obtained from the team before applying** — do not use
placeholder or example values in a real environment.

Recreate with:
```
kubectl create secret generic kk-payments-secrets \
  --from-literal=DB_PASSWORD=<real-value> \
  --from-literal=STRIPE_API_KEY=<real-value> \
  --from-literal=JWT_SECRET=<real-value> \
  -n kijani-project
```
