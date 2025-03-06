const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// 1. Function to update events from 'soon' to 'active'
exports.activateEvents = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    
    try {
      // Find all 'soon' events that should be active now
      const soonEventsSnapshot = await db.collection('events')
        .where('status', '==', 'soon')
        .where('startTime', '<', now)
        .get();
      
      if (soonEventsSnapshot.empty) {
        console.log('No events to activate');
        return null;
      }
      
      const batch = db.batch();
      const activatedEventIds = [];
      
      // Update global events to 'active'
      soonEventsSnapshot.forEach(doc => {
        batch.update(doc.ref, { status: 'active' });
        activatedEventIds.push(doc.id);
      });
      
      await batch.commit();
      console.log(`Activated ${activatedEventIds.length} events`);
      
      // Update all user events from 'awaiting' to 'active'
      await updateUserEventsStatus(activatedEventIds, 'awaiting', 'active');
      
      return null;
    } catch (error) {
      console.error('Error activating events:', error);
      return null;
    }
  });

// 2. Function to update events from 'active' to 'ended'
exports.endEvents = functions.pubsub
  .schedule('every 30 seconds')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    
    try {
      // Find all 'active' events that should be ended now
      const activeEventsSnapshot = await db.collection('events')
        .where('status', '==', 'active')
        .where('endTime', '<', now)
        .get();
      
      if (activeEventsSnapshot.empty) {
        console.log('No events to end');
        return null;
      }
      
      const batch = db.batch();
      const endedEventIds = [];
      
      // Update global events to 'ended'
      activeEventsSnapshot.forEach(doc => {
        batch.update(doc.ref, { status: 'ended' });
        endedEventIds.push(doc.id);
      });
      
      await batch.commit();
      console.log(`Ended ${endedEventIds.length} events`);
      
      // Update all user events from 'active' to 'ended'
      await updateUserEventsStatus(
        endedEventIds, 
        'active', 
        'ended', 
        { endedTime: now }
      );
      
      return null;
    } catch (error) {
      console.error('Error ending events:', error);
      return null;
    }
  });

// 3. Function to update user events from 'ended' to 'overdue'
exports.markOverdueEvents = functions.pubsub
  .schedule('every 30 seconds')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const overdueThreshold = new Date(now.toMillis() - (60 * 1000)); // 1 minute ago
    
    try {
      // Find all 'ended' user events that haven't been checked in within 1 minute
      const endedUserEventsSnapshot = await db.collectionGroup('events')
        .where('status', '==', 'ended')
        .where('endedTime', '<', admin.firestore.Timestamp.fromDate(overdueThreshold))
        .get();
      
      if (endedUserEventsSnapshot.empty) {
        console.log('No ended events to mark as overdue');
        return null;
      }
      
      const batch = db.batch();
      let count = 0;
      
      endedUserEventsSnapshot.forEach(doc => {
        batch.update(doc.ref, { 
          status: 'overdue',
          overdueTime: now
        });
        count++;
        
        // Firebase limits batched writes to 500
        if (count >= 400) {
          batch.commit();
          batch = db.batch();
          count = 0;
        }
      });
      
      if (count > 0) {
        await batch.commit();
      }
      
      console.log(`Marked ${endedUserEventsSnapshot.size} events as overdue`);
      return null;
    } catch (error) {
      console.error('Error marking events as overdue:', error);
      return null;
    }
  });

// 4. Function to update user events from 'overdue' to 'absent'
exports.markAbsentEvents = functions.pubsub
  .schedule('every 45 seconds')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const absentThreshold = new Date(now.toMillis() - (60 * 1000)); // 1 minute ago
    
    try {
      // Find all 'overdue' user events that haven't been checked in within 1 minute
      const overdueUserEventsSnapshot = await db.collectionGroup('events')
        .where('status', '==', 'overdue')
        .where('overdueTime', '<', admin.firestore.Timestamp.fromDate(absentThreshold))
        .get();
      
      if (overdueUserEventsSnapshot.empty) {
        console.log('No overdue events to mark as absent');
        return null;
      }
      
      const batch = db.batch();
      let count = 0;
      
      overdueUserEventsSnapshot.forEach(doc => {
        batch.update(doc.ref, { status: 'absent' });
        count++;
        
        if (count >= 400) {
          batch.commit();
          batch = db.batch();
          count = 0;
        }
      });
      
      if (count > 0) {
        await batch.commit();
      }
      
      console.log(`Marked ${overdueUserEventsSnapshot.size} events as absent`);
      return null;
    } catch (error) {
      console.error('Error marking events as absent:', error);
      return null;
    }
  });

// Helper function to update user events status
async function updateUserEventsStatus(eventIds, fromStatus, toStatus, additionalData = null) {
  if (eventIds.length === 0) return;
  
  try {
    // For each event, find all user events with matching status
    let totalUpdated = 0;
    
    for (const eventId of eventIds) {
      const userEventsSnapshot = await db.collectionGroup('events')
        .where(admin.firestore.FieldPath.documentId(), '==', eventId)
        .where('status', '==', fromStatus)
        .get();
      
      if (userEventsSnapshot.empty) continue;
      
      const batch = db.batch();
      let count = 0;
      
      userEventsSnapshot.forEach(doc => {
        let updateData = { status: toStatus };
        if (additionalData) {
          updateData = { ...updateData, ...additionalData };
        }
        
        batch.update(doc.ref, updateData);
        count++;
        totalUpdated++;
        
        if (count >= 400) {
          batch.commit();
          batch = db.batch();
          count = 0;
        }
      });
      
      if (count > 0) {
        await batch.commit();
      }
    }
    
    console.log(`Updated ${totalUpdated} user events from ${fromStatus} to ${toStatus}`);
    return totalUpdated;
  } catch (error) {
    console.error(`Error updating user events status: ${error}`);
    throw error;
  }
}