#include "ims.h"

bool isValidMsg (const char *str){
    if(strlen(str) > IMP_IM_MAXLEN){
        return false;
    }
    for (size_t i = 0; i < strlen(str); i++) {
        if ((isspace(str[i]) && str[i] != ' ') || !isprint(str[i])) {
            return false;
        }
    }
    return true;
}

void processIM(connection_t *data, char *username, char *im) {
    dbUser_t *target;
    if(data->user == NULL){
        sendError(data, IMP_ERROR_CLIENT_NOT_BOUND, IMP_END);
    } else if (strcmp(username,data->user->name)==0) {
        sendError(data, IMP_ERROR_BAD_COMMAND, IMP_END);
    } else if((target = lookupUser(username)) == NULL) {
        sendError(data, IMP_ERROR_USER_DOES_NOT_EXIST, username, IMP_END);
    } else if (!isFriend(data->user, target)) {
        sendError(data, IMP_ERROR_NOT_FRIEND, username, IMP_END);
    } else if (!isActive(target)) {
        sendError(data, IMP_ERROR_USER_NOT_ACTIVE, username, IMP_END);
    } else if (!isValidMsg(im)) {
        sendError(data, IMP_ERROR_BAD_COMMAND, IMP_END);
    } else {
        sendAck(data, IMP_OP_IM, username, IMP_END);
        sendOp(target->thread, IMP_OP_IM, data->user->name, im, IMP_END);
    }
}
