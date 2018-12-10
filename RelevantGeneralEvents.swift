/* We create a class that inherits from NSObject so we need Foundation. */
import Foundation
import os.log

@objc
class TPI_RelevantGeneralEvents: NSObject, THOPluginProtocol
{
    let CHAT_MAX = 25;
    var activeChannelUsers: [String:[String]] = [:]
    
    @objc
    func interceptServerInput(_ message: IRCMessage, for client: IRCClient) -> IRCMessage? {
        if (client.nicknameIsMyself(message.sender.nickname)) {
            // Always pass through our own messages
            return message;
        }

        switch (message.command) {
            case "PRIVMSG":
                userSpoke(message, for: client);
                break;
            case "JOIN":
                userJoined(message, for: client);
                return nil;
            case "PART":
                userParted(message, for: client);
                return nil;
            case "QUIT":
//                return message;
                userQuit(message, for: client);
                return nil;
            default:
                break;
        }

        return message;
    }

    func userSpoke(_ message: IRCMessage, for client: IRCClient) {
        guard let senderChannel = client.findChannel(message.param(at: 0))
            else { return };

        activeChannelUsers[senderChannel.name] = activeChannelUsers[senderChannel.name] ?? [String]();
        activeChannelUsers[senderChannel.name]?.append(message.sender.nickname);
        while ((activeChannelUsers[senderChannel.name]?.count)! > CHAT_MAX) {
            activeChannelUsers[senderChannel.name]?.removeFirst();
        }
        os_log("length - %{public}d", (activeChannelUsers[senderChannel.name]?.count)!);
    }
    
    func userJoined(_ message: IRCMessage, for client: IRCClient) {
        guard let channel = client.findChannel(message.param(at: 0))
            else { return };
        
        // Silently add user to member list
        let alreadyInMemberList = channel.memberList.contains { (user) -> Bool in
            return user.user.nickname == message.sender.nickname;
        }
        if (!alreadyInMemberList) {
            let user = client.findUserOrCreate(message.sender.nickname);
            client.add(user);
            channel.add(user);
        }

        if (!recentlyActive(message.sender.nickname, in: channel)) {
            return;
        }

        let text = TXLocalizedString(Bundle.main, "IRC[ziu-p9]", getVaList([message.sender.nickname, message.sender.username ?? "", message.sender.address?.appendingIRCFormattingStop ?? ""]));

        performBlock(onMainThread: {
            client.print(text,
                by: nil,
                in: channel,
                as: TVCLogLineType.join,
                command: message.command
            );
        })
    }

    func userParted(_ message: IRCMessage, for client: IRCClient) {
        guard let channel = client.findChannel(message.param(at: 0))
            else { return };

        removeNickname(message.sender.nickname, from: channel);

        if (!recentlyActive(message.sender.nickname, in: channel)) {
            return;
        }

        var text = TXLocalizedString(Bundle.main, "IRC[nkr-kf]", getVaList([message.sender.nickname, message.sender.username ?? "", message.sender.address?.appendingIRCFormattingStop ?? ""]));

        let comment = message.param(at: 1);
        if (comment.count > 0) {
            text = TXLocalizedString(Bundle.main, "IRC[ozy-6i]", getVaList([text, comment.appendingIRCFormattingStop]));
        }

        performBlock(onMainThread: {
            client.print(text,
                by: nil,
                in: channel,
                as: TVCLogLineType.part,
                command: message.command
            );
        })
    }

    func userQuit(_ message: IRCMessage, for client: IRCClient) {
        var text = TXLocalizedString(Bundle.main, "IRC[53b-dm]", getVaList([message.sender.nickname, message.sender.username ?? "", message.sender.address?.appendingIRCFormattingStop ?? ""]));
        
        let comment = message.param(at: 0);
        if (comment.count > 0) {
            text = TXLocalizedString(Bundle.main, "IRC[tok-st]", getVaList([text, comment.appendingIRCFormattingStop]));
        }

        client.channelList.forEach { (channel) in
            removeNickname(message.sender.nickname, from: channel);

            if (!recentlyActive(message.sender.nickname, in: channel)) {
                return;
            }

            performBlock(onMainThread: {
                client.print(text,
                    by: nil,
                    in: channel,
                    as: TVCLogLineType.quit,
                    command: message.command
                );
            })
        }
    }

    func recentlyActive(_ nickname: String, in channel: IRCChannel) -> Bool {
        return activeChannelUsers[channel.name]?.contains(nickname) ?? false;
    }

    func removeNickname(_ nickname: String, from channel: IRCChannel) {
        // This should be sufficent
        channel.removeMember(withNickname: nickname);

//        channel.memberList.filter({ (user) -> Bool in
//            return user.user.nickname == nickname;
//        }).forEach({ (user) in
//            channel.removeMember(user);
//        })
    }
}
