# Troubleshooting

## Deleting AWS instances

If you have some issues with creating new clusters because profile with the same name already exists you can try to delete them:

To get list of instances:

```
aws iam list-instance-profiles
```

When you find instance to delete:

```
aws iam delete-instance-profile --instance-profile-name <here-name-of-instance>`
```